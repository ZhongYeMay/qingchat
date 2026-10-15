set -eu
mkdir -p public/assets
cp index.html share.html style.css app.js share.js sw.js manifest.webmanifest public/
cp assets/* public/assets/
