# Project website and Schoolbell demo

[Русский](README.md)

RU/EN landing sources live in site/. build-site.py renders the demo from packages/schoolbell/router-page/root and injects site/demo.js. The MP3 and NOTICE are copied from the pinned repository assets. No separate UI fork or backend is needed.

```sh
make check-site
python3 -m http.server 8769 --bind 127.0.0.1 --directory out/site
```

Open http://localhost:8769/. Python3 and Node.js are required for checks; there are no npm dependencies.

Data stays in this site's localStorage (openwrt-schoolbell-public-demo-v1), or tab memory when unavailable. Save, preview, the last80journal events and time-zone settings are local simulations, not full server validation or crash guarantees. No hardware commands or automatic bells are possible. The MP3 plays only after a browser-button click. Reset affects demo data only and asks for confirmation.

After merging and passing CI for the exact main commit, the owner selects Settings → Pages → Source: GitHub Actions and manually runs the GitHub Pages workflow on main. It never deploys on push. Expected URL after successful deployment: https://viacheslavmezentsev.github.io/openwrt-modbus-core/ . Do not treat that URL as published until deployment succeeds.

The workflow follows [GitHub Pages documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages). No private hardware logs or configuration enter the site.
