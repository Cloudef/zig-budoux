# zig-budoux

[Budoux](https://github.com/google/budoux) for Zig (and C)

> [!NOTE]
> Thai model is disabled due to this upstream issue https://github.com/google/budoux/issues/504
> This implementation does not encode strings to utf16 (allocation free)
> Unfortunately this means we can't use the thai model as it contains keys that are slices of utf16 bytes

---

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Project is tested on zig version 0.12.0-dev.2825+dd1fc1cb8

## Example

### Zig

```zig
const budoux = @import("zig-budoux");
var model = try budoux.init(allocator, .ja);
defer model.deinit(allocator);
var iter = model.iterator("今日は天気です。");
try std.testing.expectEqualSlices(u8, "今日は", iter.next().?);
try std.testing.expectEqualSlices(u8, "天気です。", iter.next().?);
```

### C

```c
#include <budoux.h>
BudouxModel model = budoux_init(budoux_model_ja);
BudouxChunkIterator iter = budoux_iterator_init(model, "今日は天気です。");
BudouxChunk chunk;
chunk = budoux_iterator_next(&iter); // 今日は
chunk = budoux_iterator_next(&iter); // 天気です。
budoux_deinit(model);
```

> [!NOTE]
> zig-budoux does not allocate any strings, thus it won't add any html markup or zero width spaces.
> However with `model.iterator` it is simple to construct strings for your needs.
> To parse html you need to bring your own html parser.

## Depend

`build.zig.zon`
```zig
.zig_budoux = .{
  .url = "https://github.com/Cloudef/zig-budoux/archive/{COMMIT}.tar.gz",
  .hash = "{HASH}",
},
```

`build.zig`
```zig
const zig_budoux = b.dependency("zig_budoux", .{}).module("zig-budoux");
exe.root_module.addImport("zig-budoux", zig_budoux);
```
