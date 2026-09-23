export interface MarketplaceLink {
  name: string;
  url: string;
  affiliate: boolean;
}

// Catalog membership is not hardware verification. Keep evidence explicit per model.
const models = [
  {
    id: "auto-max",
    brand: "Nike Adapt",
    model: "Auto Max",
    year: "2020",
    colorway: "Triple Black",
    image: "/images/auto-max.jpg",
    width: 1614,
    height: 937,
    verified: true,
    description:
      "Air Max attitude. A fit all its own. The everyday silhouette at the heart of OpenAdapt’s development.",
    status: "Verified · firmware 2.4.3M",
    detail:
      "Control verified on the development pair. Fresh setup and fit calibration are still being tested.",
    photoSource:
      "https://www.goat.com/sneakers/adapt-auto-max-triple-black-cz6799-002",
    stockx: "https://stockx.com/nike-adapt-auto-max-triple-black-us-charger",
  },
  {
    id: "adapt-bb",
    stockx: "https://stockx.com/nike-adapt-bb-black-pure-platinum",
    brand: "Nike Adapt",
    model: "BB",
    year: "2019",
    colorway: "Black",
    image: "/images/adapt-bb.jpg",
    width: 1250,
    height: 702,
    verified: false,
    description:
      "Where Adapt met the court. A sculpted knit upper, an icy sole, and a new way to lace up.",
    status: "Not yet verified",
    detail:
      "Included in the app’s shoe catalog. OpenAdapt connection and control have not been verified on this model.",
    photoSource: "https://www.goat.com/sneakers/adapt-bb-black-ao2582-001",
  },
  {
    id: "adapt-bb-2",
    stockx: "https://stockx.com/nike-adapt-bb-2-black",
    brand: "Nike Adapt",
    model: "BB 2.0",
    year: "2020",
    colorway: "NBA ASG 2020",
    image: "/images/adapt-bb-2.jpg",
    width: 1250,
    height: 660,
    verified: false,
    description:
      "The second chapter on court. A bolder silhouette, textured Swoosh, and self-lacing design built to stand out.",
    status: "Not yet verified",
    detail:
      "Included in the app’s shoe catalog. OpenAdapt connection and control have not been verified on this model.",
    photoSource:
      "https://www.goat.com/sneakers/adapt-bb-2-0-all-star-2020-cv2441-001",
  },
  {
    id: "adapt-huarache",
    stockx: "https://stockx.com/nike-adapt-huarache-white-black",
    brand: "Nike Adapt",
    model: "Huarache",
    year: "2019",
    colorway: "White / Black",
    image: "/images/adapt-huarache.jpg",
    width: 1250,
    height: 627,
    verified: false,
    description:
      "A familiar icon, reimagined. The Huarache’s unmistakable shape meets the possibilities of a connected shoe.",
    status: "Not yet verified",
    detail:
      "Included in the app’s shoe catalog. OpenAdapt connection and control have not been verified on this model.",
    photoSource:
      "https://www.goat.com/sneakers/adapt-huarache-white-black-bv6397-110",
  },
  {
    id: "jordan-11-adapt",
    stockx: "https://stockx.com/air-jordan-11-adapt-white",
    brand: "Air Jordan",
    model: "11 Adapt",
    year: "2020",
    colorway: "White",
    image: "/images/jordan-11-adapt.jpg",
    width: 1250,
    height: 789,
    verified: false,
    description:
      "Twenty-five years of an icon. Patent leather, an icy outsole, and an electric new chapter for the Jordan 11.",
    status: "Not yet verified",
    detail:
      "Included in the app’s shoe catalog. OpenAdapt connection and control have not been verified on this model.",
    photoSource:
      "https://www.goat.com/sneakers/air-jordan-11-adapt-25th-anniversary-da7990-100",
  },
];

export const shoes = models.map((shoe) => ({
  ...shoe,
  // Replace individual URLs with approved tracking links and enable their affiliate flag.
  links: [
    {
      name: "StockX",
      url: shoe.stockx,
      affiliate: false,
    },
    {
      name: "eBay",
      url: `https://www.ebay.com/sch/i.html?_nkw=${encodeURIComponent(`${shoe.brand} ${shoe.model}`)}`,
      affiliate: false,
    },
  ] satisfies MarketplaceLink[],
}));

export const hasAffiliate = shoes.some((shoe) =>
  shoe.links.some((link) => link.affiliate),
);
