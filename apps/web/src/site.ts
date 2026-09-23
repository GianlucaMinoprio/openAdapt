/** Launch controls: never advertise a download or public source until it exists. */
export const site = {
  name: "OpenAdapt",
  url: "https://openadapt.app",
  repo: "https://github.com/GianlucaMinoprio/openAdapt",
  repositoryPublic: false,
  branch: "master",
  testflight: "",
  appStore: "",
  stockx: {
    url: "https://stockx.com/nike-adapt-auto-max-triple-black-us-charger",
    affiliate: false,
  },
  goat: {
    url: "https://www.goat.com/sneakers/adapt-auto-max-triple-black-cz6799-002",
    affiliate: false,
  },
};
export const source = (path: string) =>
  `${site.repo}/tree/${site.branch}/${path}`;
