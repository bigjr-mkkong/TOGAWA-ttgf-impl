"""Check Docker forwarding without starting containers: python3 -m unittest discover -s test -p test_docker_launcher.py."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class DockerLauncherTest(unittest.TestCase):
    def test_clean_without_cocotb_or_simulators(self):
        makefile = Path(__file__).resolve().with_name("Makefile")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tools = root / "bin"
            tools.mkdir()
            (tools / "rm").symlink_to(shutil.which("rm"))
            generated = ("sim_build/gl/stale", "sim_build/rtl/stale", "results.xml",
                         "results-arbiter.xml", "tb.fst", "tb.vcd")
            inputs = ("tb.v", "gate_level_netlist.v", "program.json")
            for name in generated + inputs:
                artifact = root / name
                artifact.parent.mkdir(parents=True, exist_ok=True)
                artifact.write_text("fixture\n")
            result = subprocess.run([shutil.which("make"), "-f", str(makefile), "clean"],
                                    cwd=root, env={"PATH": str(tools)},
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            for name in generated:
                self.assertFalse((root / name).exists(), name)
            for name in inputs:
                self.assertEqual((root / name).read_text(), "fixture\n")

    def test_make_targets_select_gf180_and_only_harden_starts_a_flow(self):
        root = Path(__file__).resolve().parents[1]
        for target in ("test-unit", "test-full", "harden", "report", "cmd"):
            with self.subTest(target=target):
                result = subprocess.run(["make", "-n", target], cwd=root,
                                        capture_output=True, text=True, check=True)
                self.assertIn("--env PDK=gf180mcuD", result.stdout)
                self.assertIn("tt-gf180-env:latest", result.stdout)
                self.assertEqual("--harden" in result.stdout, target == "harden")
                if target in ("harden", "report"):
                    self.assertIn("--pdk gf180mcuD", result.stdout)
                if target == "cmd":
                    self.assertIn("-it", result.stdout)
                    self.assertIn("bash --noprofile --norc", result.stdout)
                if target in ("test-unit", "test-full"):
                    self.assertEqual("make -C test;" in result.stdout, target == "test-full")
                    self.assertEqual("make -C test unit;" in result.stdout, target == "test-unit")

    def test_report_requires_synthesis_and_prints_both_reports(self):
        makefile = Path(__file__).resolve().parents[1] / "Makefile"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            # Run the report recipe locally with a fixture in place of tt_tool.
            command = ["make", "-f", str(makefile), "-o", "setup", "report",
                       "DOCKER_RUN=", "IMAGE=env"]
            result = subprocess.run(command, cwd=root, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("No synthesis report yet", result.stderr)
            report = root / "runs/wokwi/10-yosys-synthesis/reports/stat.rpt"
            report.parent.mkdir(parents=True)
            report.write_text("Synthesis fixture: 123 cells\n")
            tool = root / "tt/tt_tool.py"
            tool.parent.mkdir()
            tool.write_text('#!/bin/sh\n[ "$*" = "--pdk gf180mcuD --print-stats" ] || exit 9\n'
                            'echo "Routing fixture: 456 um"\n')
            tool.chmod(0o755)
            result = subprocess.run(command, cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Synthesis fixture: 123 cells", result.stdout)
            self.assertIn("Routing fixture: 456 um", result.stdout)

    def test_forwarding_preserves_arguments_and_exit_status(self):
        source = Path(__file__).resolve().parents[1] / "scripts/docker"
        with tempfile.TemporaryDirectory() as directory:
            client = Path(directory) / "client"
            client.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\nexit 7\n')
            client.chmod(0o755)
            launcher = Path(directory) / "docker"
            launcher.write_text(source.read_text().replace('/usr/local/bin/docker-host', str(client)))
            for args, expected in (
                (["run", "--rm", "image", "argument with spaces"],
                 ["run", "--network", "host", "--rm", "image", "argument with spaces"]),
                (["image", "inspect", "image"], ["image", "inspect", "image"]),
            ):
                with self.subTest(args=args):
                    result = subprocess.run(["sh", str(launcher), *args], capture_output=True, text=True)
                    self.assertEqual(result.stdout.splitlines(), expected)
                    self.assertEqual(result.returncode, 7)
