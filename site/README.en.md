# Project website and Schoolbell demo

Pages: separate [guide](schoolbell-guide.en.html) for build, installation and first startup (draft), linked from demo notice/module card. Shared theme, return links, inline SVG diagrams from diagrams/. Verified commands/images follow new-bench acceptance; this page never flashes devices.

Selected-plan .sbp export and read-only import preview are available in Calendar. [Workflow and limits](../docs/packages/schoolbell/PORTABLE_PLAN_PAGES.en.md).

[Русский](README.md)

RU/EN landing sources live in site/. build-site.py renders the demo from packages/schoolbell/router-page/root and injects site/demo.js. The MP3 and NOTICE are copied from the pinned repository assets. No separate UI fork or backend is needed.

```sh
make check-site
python3 -m http.server 8769 --bind 127.0.0.1 --directory out/site
```

Open http://localhost:8769/. Python3 and Node.js are required for checks; there are no npm dependencies.

Data stays in this site's localStorage (openwrt-schoolbell-public-demo-v1), or tab memory when unavailable. Save, preview, the last80journal events and time-zone settings are local simulations, not full server validation or crash guarantees. No hardware commands or automatic bells are possible. Bundled MP3 files play only after a browser-button click. Reset affects demo data only and asks for confirmation.

After merging and passing CI for the exact main commit, the owner selects Settings → Pages → Source: GitHub Actions and manually runs the GitHub Pages workflow on main. It never deploys on push. Expected URL after successful deployment: https://viacheslavmezentsev.github.io/openwrt-modbus-core/ . Do not treat that URL as published until deployment succeeds.

The workflow follows [GitHub Pages documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages). No private hardware logs or configuration enter the site.

Page and demo footers show the UTC build time and short commit; build-info.json contains the full SHA. Tracked local changes are labeled; missing Git yields unknown. This is the build time, not the page load time or a guaranteed deployment time. Updating main does not republish the site automatically.

The demo includes test.mp3 and five bundled melodies. Each populated row plays its own file in the browser; empty user slots cannot play. There is no autoplay or router command.

Since 5.1.0 the demo shares the working named-range editor and payload checks. It supports device-free training/preparation with bundled melodies only. Portable .sbp export and read-only import preview are available. A shared oracle checks civil preview parity with Lua; DST, clock trust and actual device resources are not emulated.

The Guide button sits to the right of the demo notice (below it on narrow screens). Feedback shows the full Git commit, UTC build date and dirty-build marker beside the authors. These identify the Pages build, not an installed IPK.

Device references: `site/devices/` contains bilingual model-specific guides and artifact metadata. OEM binaries and source snapshots stay in local archives, outside Git/Pages; public mirror URLs remain unset until publication is authorized.

Training is a separate training.en.html page with practical post-setup exercises, linked from the demo, module card and guide. It performs no device actions.
