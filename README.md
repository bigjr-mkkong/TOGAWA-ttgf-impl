![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Tiny Tapeout Verilog Project Template

- [Read the documentation for project](docs/info.md)

## Local GF180 environment

Build the image using the existing `tt-sky130-env:latest` image as its base:

```sh
docker build --network host -t tt-gf180-env:latest .
```

It retains the existing Tiny Tapeout support tools and installs Verilator 5.046,
cocotb 2.1.0, and LibreLane 3.0.14 with `PDK=gf180mcuD`, following the
[local-hardening guide](https://tinytapeout.com/guides/local-hardening/).
The host only needs Docker and Make; no host simulator installation is required.

```sh
make test-unit # Arbiter/SPI cocotb tests and Python checks
make test-full # Full CPU programs with pre/post memory checks
make harden   # Generate configuration, then run synthesis through routing
make report   # Print the synthesis report and routing statistics
make cmd      # Interactive shell, with the Python environment already active
```

Inside `make cmd`, run the support tools directly, for example:

```sh
./tt/tt_tool.py --pdk "$PDK" --create-user-config
./tt/tt_tool.py --pdk "$PDK" --print-top-module
```

Pass `--pdk "$PDK"` when invoking `tt_tool.py` directly: its default is SKY130.
The Make targets always select GF180. They copy `tt/` from the image on first use
and keep the PDK cache in `.pdk/` and container home in `.tt-home/`.
LibreLane downloads the GF180 PDK and its tool image on first hardening if needed.
`make harden` replaces `runs/wokwi`; save any previous run you want to retain.
`make report` requires synthesis results and does not start a flow.

The launcher uses the host Docker socket and host networking so LibreLane can
start its tool container, with the project mounted at the same absolute path.
Generated files belong to your host user. RTL waveforms are under
`test/sim_build/`; see [test/README.md](test/README.md) for individual test targets.

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Set up your Verilog project

1. Add your Verilog files to the `src` folder.
2. Edit the [info.yaml](info.yaml) and update information about your project, paying special attention to the `source_files` and `top_module` properties. If you are upgrading an existing Tiny Tapeout project, check out our [online info.yaml migration tool](https://tinytapeout.github.io/tt-yaml-upgrade-tool/).
3. Edit [docs/info.md](docs/info.md) and add a description of your project.
4. Adapt the testbench to your design. See [test/README.md](test/README.md) for more information.

The GitHub action will automatically build the ASIC files using [LibreLane](https://www.zerotoasiccourse.com/terminology/librelane/).

## Enable GitHub actions to build the results page

- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
  - Bluesky [@tinytapeout.com](https://bsky.app/profile/tinytapeout.com)
