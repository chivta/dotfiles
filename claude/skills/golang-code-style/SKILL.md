---
name: golang-code-style
description: Go/Golang code style — dependency wiring, if statements, and when to split a function. Use whenever writing, reviewing, or refactoring Go code.
---

# Go style

## Wiring in main

All wiring happens in `func main()`, in one place: read config, open connections, construct clients, repositories and services, then run. Setup stays inline in main rather than in `newXService()` / `newXClient()` helpers, so the whole dependency graph and every startup failure point read top to bottom in one function.

## Multi-value calls go on their own line

Call a function that returns more than one value on its own line, then check the results:

```go
site, err := siteRepository.GetSite(ctx, siteID)
if err != nil {
    log.Fatalf("site %d: siteRepository.GetSite failed: %v", siteID, err)
}
```

Never `if site, err := siteRepository.GetSite(ctx, siteID); err != nil {`. On its own line the call reads as a step of the flow, and its results stay in scope for the code after the check. A single-value init such as `if err := cleanenv.ReadEnv(&cfg); err != nil` is fine.

## Locality of behaviour over short functions

When logic reads as one flow — get data, parse it, normalize it, act on it — keep it in one function, however long. A reviewer then reads it once, top to bottom; split into three-line helpers, the same flow makes them jump between definitions and rebuild the order in their head. Extract a function only when it is called from several places, or when its name says everything and nobody needs to open it, such as `splitList` or `parseSiteIDs`. When the linter's length check objects, put `//nolint:funlen` on the function instead of splitting it.

A CLI that invalidates CloudFront distributions, given directly or looked up by site ID or domain. Before, the flow is scattered across helpers of a few lines each:

```go
func main() {
    ...
    distributions, err := collectDistributions(ctx, splitList(*distributionList), siteIDs, splitList(*domainList))
    ...
    cloudFrontCache, err := newCloudFrontCache(ctx)
    ...
}

func collectDistributions(ctx context.Context, distributions []string, siteIDs []uint64, domains []string) ([]string, error) {
    siteService, err := newSiteService()
    ...
    finder := &siteFinder{siteService: siteService}
    for _, siteID := range siteIDs {
        site, err := finder.byID(ctx, siteID)
        ...
        distribution, err := siteDistribution(site)
        ...
        distributions = append(distributions, distribution)
    }
    ...
    return unique(distributions), nil
}

func (finder *siteFinder) byID(ctx context.Context, siteID uint64) (*common.Site, error)     { ... }
func (finder *siteFinder) byDomain(ctx context.Context, domain string) (*common.Site, error) { ... }
func siteDistribution(site *common.Site) (string, error)                                    { ... }
func unique(items []string) []string                                                        { ... }
func newSiteService() (*services.SiteService, error)                                        { ... }
func newCloudFrontCache(ctx context.Context) (*cache.CloudFrontCache, error)                { ... }
```

After, the same flow sits in main in the order it runs, and `unique` became a set inside the loop that already walks the distributions:

```go
//nolint:funlen
func main() {
    ...
    if len(siteIDs) > 0 || len(domains) > 0 {
        var dbCfg dbConfig
        if err := cleanenv.ReadEnv(&dbCfg); err != nil {
            log.Fatal(err)
        }
        ...
        db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
        ...
        siteRepository := repositories.NewSiteRepository(db)
        settingsRepository := repositories.NewSettingsRepository(db, repositories.NewVariableRepository(db))

        var sites []*models.Site
        for _, siteID := range siteIDs {
            site, err := siteRepository.GetSite(ctx, uint(siteID))
            ...
            sites = append(sites, site)
        }
        for _, domain := range domains {
            site, err := siteRepository.GetSiteBySlug(ctx, domain)
            ...
            sites = append(sites, site)
        }
        for _, site := range sites {
            settings, err := settingsRepository.FindBySiteID(ctx, site.ID)
            ...
            distributions = append(distributions, settings.Distribution)
        }
    }

    var cfCfg cloudFrontConfig
    ...
    cloudFrontCache := cache.NewCloudFrontCache(cloudfront.NewFromConfig(awsCfg), callerReferencePrefix)

    invalidated := make(map[string]struct{}, len(distributions))
    for _, distribution := range distributions {
        if _, ok := invalidated[distribution]; ok {
            continue
        }
        invalidated[distribution] = struct{}{}
        if err := cloudFrontCache.InvalidateCache(ctx, distribution, []string{*path}); err != nil {
            ...
        }
    }
}
```
