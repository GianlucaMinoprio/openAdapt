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
- Marketplace URLs in `src/shoes.ts`: replace only with real product or approved affiliate links. Set the matching `affiliate` field to `true` when the URL earns commission. The site then renders a nearby disclosure and marks that link `rel="sponsored"`.

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

StockX documents an affiliate program through Impact. Apply and use approved tracking links once accepted; current program terms must be verified in the account before making commission claims. eBay also offers the eBay Partner Network, including tracked links to products and search results. Apply separately, then use real campaign links; commission rates depend on the category and qualifying purchase terms. No official GOAT sneaker affiliate program was verified. GOAT has been removed from the shopping options. Photo-source credits remain because the gallery uses GOAT product photography. No affiliate application was submitted by this website task.

Sources:
- https://stockx.com/news/en-us/affiliate-faq/
- https://stockx.com/news/en-us/stockx-affiliate-program/
- https://partnernetwork.ebay.com/our-program
- https://partnernetwork.ebay.com/our-program/rate-card
- https://partnernetwork.ebay.com/resources/create-your-affiliate-link

## Assets and privacy

- The sneaker mark is the project's original MIT-licensed artwork from `assets/brand/sneaker.svg`.
- The iPhone screenshot is the project’s own labeled Simulator demo capture. The Omarchy view is a labeled HTML/CSS theme preview matching the native panel’s controls, using the official Tokyo Night palette: https://raw.githubusercontent.com/basecamp/omarchy/master/themes/tokyo-night/colors.toml
- Omarchy’s logo and wordmark come from https://omarchy.org/brand/ and retain their default brand green. These third-party brand assets are not covered by the OpenAdapt MIT license.
- Product photos come from the matching GOAT listing recorded in each model’s `photoSource` field in `src/shoes.ts`. Auto Max: https://www.goat.com/sneakers/adapt-auto-max-triple-black-cz6799-002 . Third-party product photography is not covered by this repository's MIT license. Replace with owner photography or approved affiliate creative when available.
- Inter and Inter Tight are self-hosted, with their font licenses in `public/fonts/`.
- No analytics scripts, email collection, cloud app backend, Bluetooth access, or cookies are added by the website. The interactive demo is browser-local simulation.
- Search metadata, a social preview, sitemap, robots file, security headers, privacy page, and a 404 page are included.

## Shared iPhone privacy policy

`npm run build` refreshes `src/content/app-privacy.txt` from the iPhone policy when building from the full repository. Standalone website uploads use the checked-in copy. The `/app-privacy` route keeps the app policy separate from website privacy.

## Shoe gallery

The five models mirror the native app catalog, not five verified profiles. Only Auto Max firmware 2.4.3M is marked verified. Use `src/shoes.ts` to update model evidence and per-link affiliate flags. The carousel is server-rendered, uses native scroll snap and touch scrolling, has keyboard/thumbnail/previous/next controls, and never advances automatically. Reduced Motion disables smooth scrolling. Without JavaScript, all cards and model anchor links remain accessible.

Photo sources (GOAT, retrieved September 23, 2026):
- Adapt BB: https://image.goat.com/transform/v1/attachments/product_template_additional_pictures/images/079/299/458/original/487879_01.jpg.jpeg
- Adapt BB 2.0: https://image.goat.com/transform/v1/attachments/product_template_additional_pictures/images/080/337/367/original/589235_01.jpg.jpeg
- Adapt Huarache: https://image.goat.com/transform/v1/attachments/product_template_additional_pictures/images/079/333/407/original/546697_01.jpg.jpeg
- Air Jordan 11 Adapt: https://image.goat.com/transform/v1/attachments/product_template_additional_pictures/images/100/071/868/original/704154_01.jpg.jpeg

### Application preparation — September 23, 2026

Both official application flows have been opened. eBay requires the owner to sign in before its application form is accessible. StockX requires acceptance of its Publisher Agreement before account setup; owner approval is pending. No application has been submitted and no tracking link has been issued.

StockX’s current offer shows 3% on qualifying sneaker sales to new customers, 1% to existing customers, and 15-day last-click attribution. Section 2.2 restricts links near competing marketplaces and use of creative assets. Before activating StockX tracking, use separate StockX shopping pages without competitor links, or obtain an explicit exception. Keep ordinary links and the no-commission disclosure until actual enrollment and tracking details are verified.

Application description: OpenAdapt is an independent software project working to restore app control to Nike Adapt shoes. Its website presents the iPhone and Omarchy clients, documents compatibility limits, and introduces the five-model Adapt family. Marketplace links help visitors find relevant resale listings. Promotion is through editorial content on https://openadapt.app; no paid advertising, coupon distribution, or incentivized traffic is planned. Do not invent audience or traffic metrics for application forms.
