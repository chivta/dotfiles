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

When logic reads as one flow — get data, parse it, normalize it, act on it — split it only at step boundaries: an extracted function holds one whole step, such as resolving sites into distributions, and the caller lists the steps in the order they run. Keep functions within `funlen` by splitting at the next step boundary. A helper that does a piece of a step makes the reviewer jump between definitions and rebuild the order in their head, so create one only when it has several callers, like `splitList` with three; a piece with one caller, like parsing the site IDs of one flag, stays inline at that caller.

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

After, main runs the steps in order — parse, wire the DB, resolve sites into distributions, wire CloudFront, invalidate. Resolution is one function holding its whole step, site-ID parsing is inline in main, `splitList` stays a helper for its three call sites, and `unique` became a set inside the loop that already walks the distributions:

```go
func main() {
    ...
    flag.Parse()
    ...
    var siteIDs []uint64
    for _, rawSiteID := range splitList(*siteIDList) {
        siteID, err := strconv.ParseUint(rawSiteID, 10, 64)
        if err != nil {
            log.Fatalf("invalid site-id %q: %v", rawSiteID, err)
        }
        siteIDs = append(siteIDs, siteID)
    }
    distributions := splitList(*distributionList)
    domains := splitList(*domainList)
    ctx := context.Background()

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

        siteDistributions, err := resolveDistributions(ctx, siteRepository, settingsRepository, siteIDs, domains)
        if err != nil {
            log.Fatal(err)
        }
        distributions = append(distributions, siteDistributions...)
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

func splitList(list string) []string { ... }

func resolveDistributions(
    ctx context.Context,
    siteRepository *repositories.SiteRepository,
    settingsRepository *repositories.SettingsRepository,
    siteIDs []uint64,
    domains []string,
) ([]string, error) {
    var sites []*models.Site
    for _, siteID := range siteIDs {
        site, err := siteRepository.GetSite(ctx, uint(siteID))
        if err != nil {
            return nil, fmt.Errorf("site %d: siteRepository.GetSite failed: %w", siteID, err)
        }
        sites = append(sites, site)
    }
    for _, domain := range domains {
        site, err := siteRepository.GetSiteBySlug(ctx, domain)
        ...
        sites = append(sites, site)
    }

    distributions := make([]string, 0, len(sites))
    for _, site := range sites {
        settings, err := settingsRepository.FindBySiteID(ctx, site.ID)
        ...
        distributions = append(distributions, settings.Distribution)
    }
    return distributions, nil
}
```
