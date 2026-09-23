# OpenAdapt website

A static Astro site for openadapt.app. Native client source remains outside this app. The build uploads only this directory to Vercel.

## Local development

```sh
cd apps/web
npm ci
npm run dev
npm run check
npm run build
```

## Launch switches

Edit `src/site.ts` and redeploy:

- `repositoryPublic`: leave `false` while the repository is private. Once public release is approved and the repository actually becomes public, set `true` to activate GitHub star, source, clone, and contribution links. This flag never changes GitHub visibility itself.
- `testflight`: set to the real approved public invitation URL. An empty value renders “coming soon” and links to the release status.
- `appStore`: set to the actual Apple listing after release.
- Marketplace URLs: replace only with real product or approved affiliate links. Set the matching `affiliate` field to `true` when the URL earns commission. The site then renders a nearby disclosure and marks that link `rel="sponsored"`.

Compatibility copy reflects the repository's September 22, 2026 documentation: Auto Max 2.4.3M is the verified profile; new enrollment/calibration and broader iPhone hardware validation are pending. Update the FAQ, compatibility note, and client copy when new hardware evidence or release status changes. Client ideas are not advertised as implemented features.

## Deploy

Vercel project: `openadapt` in `gianlus-projects`. The Git integration builds `apps/web` from the monorepo. Automatic production deployments use `master` once the website PR is merged. Run manual deployments from the repository root so Vercel can resolve that root directory.

```sh
# From the repository root:
npx vercel link --project openadapt --scope gianlus-projects
npx vercel --prod --scope gianlus-projects
```

Use the DNS records Vercel reports for this project when connecting `openadapt.app`. Do not replace unrelated Cloudflare mail, verification, or other subdomain records. The apex is configured in Cloudflare as a DNS-only CNAME to `0d226bda3b0ff7f4.vercel-dns-017.com`. Vercel reports valid configuration. A `www` redirect is optional and separate.

## Referral program

StockX documents an affiliate program through Impact. Apply and use approved tracking links once accepted; current program terms must be verified in the account before making commission claims. No official GOAT sneaker affiliate program was verified. GOAT links therefore remain ordinary product links unless a direct arrangement is established. No affiliate application was submitted by this website task.

Sources:
- https://stockx.com/news/en-us/affiliate-faq/
- https://stockx.com/news/en-us/stockx-affiliate-program/

## Assets and privacy

- The sneaker mark is the project's original MIT-licensed artwork from `assets/brand/sneaker.svg`.
- App screenshots are the project's own labeled Simulator/native demo captures, resized and encoded as WebP.
- The Auto Max product photograph is from the GOAT listing linked in the footer: https://www.goat.com/sneakers/adapt-auto-max-triple-black-cz6799-002 . Third-party product photography is not covered by this repository's MIT license. Replace with owner photography or approved affiliate creative when available.
- Inter and Inter Tight are self-hosted, with their font licenses in `public/fonts/`.
- No analytics scripts, email collection, cloud app backend, Bluetooth access, or cookies are added by the website. The interactive demo is browser-local simulation.
- Search metadata, a social preview, sitemap, robots file, security headers, privacy page, and a 404 page are included.

## Shared iPhone privacy policy

`npm run build` refreshes `src/content/app-privacy.txt` from the iPhone policy when building from the full repository. Standalone website uploads use the checked-in copy. The `/app-privacy` route keeps the app policy separate from website privacy.
