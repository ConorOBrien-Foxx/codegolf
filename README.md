# codegolf

## building

The site is built with [`./build.rb`](./build.rb), and parses the files in `/build`. This folder containers Mardkwon files, named with the problem ID (`GXXXXX.md`) with JSON front matters, formatted as such:

```
---
{
    "name": string,
    "tags: [string...],
    "par": [[string, number]...],
    other options...
}
---
Challenge text
```

The build folder also contains some HTML templates.