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

## contributing

If you want to feature a challenge that ***you wrote*** and can release under GPLv3.0, please feel free to make a pull request. Please, only one challenge per pull request, and name your file GXXXXX.md, rather than giving it an ID yourself. I will assign the ID before accepting your pull request.
