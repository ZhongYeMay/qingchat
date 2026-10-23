set -eu
mkdir -p public/assets
cp index.html share.html invite.html style.css app.js share.js invite.js sw.js manifest.webmanifest public/
cp assets/* public/assets/
