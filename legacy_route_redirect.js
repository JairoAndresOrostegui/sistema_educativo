"use strict";

// Old shared Flutter links must be normalized before the router starts.
// The fragment never reaches Hosting, so a server redirect cannot do this.
(function () {
  function cleanLegacyRoute(href, baseHref) {
    const current = new URL(href);
    const base = new URL(baseHref, current);
    if (current.origin !== base.origin ||
        ![base.pathname, `${base.pathname}index.html`].includes(current.pathname) ||
        !current.hash.startsWith("#/")) return null;

    const route = current.hash.slice(2);
    // Only app-relative paths. Never navigate to another site or above base.
    if (route.startsWith("/") || route.includes("\\")) return null;
    const target = new URL(route || ".", base);
    if (target.origin !== base.origin || !target.pathname.startsWith(base.pathname)) return null;
    for (const [key, value] of current.searchParams) {
      if (!target.searchParams.has(key)) target.searchParams.append(key, value);
    }
    return target.pathname + target.search + target.hash;
  }

  if (typeof module !== "undefined" && module.exports) {
    module.exports = {cleanLegacyRoute};
  }
  if (typeof window !== "undefined") {
    const officialSite = document.documentElement?.dataset?.schoolSite === "official";
    function normalizeCurrentLocation() {
      const clean = cleanLegacyRoute(window.location.href,
          officialSite ? new URL("/", window.location.href).href : document.baseURI);
      if (clean !== null) {
        if (officialSite) window.location.replace(clean);
        else window.history.replaceState(window.history.state, "", clean);
      }
    }
    normalizeCurrentLocation();
    // A legacy link opened in the already-loaded native home is a same-document
    // navigation: the head scripts do not run again, but hashchange does.
    if (officialSite) window.addEventListener?.('hashchange', normalizeCurrentLocation);
  }
})();
