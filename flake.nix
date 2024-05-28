{
  description = "zig-budoux flake";

  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs = { zig2nix, ... }: let
    flake-utils = zig2nix.inputs.flake-utils;
  in (flake-utils.lib.eachDefaultSystem (system: let
      # Zig flake helper
      # Check the flake.nix in zig-flake project for more options:
      # <https://github.com/Cloudef/mach-flake/blob/master/flake.nix>
      env = zig2nix.outputs.zig-env.${system} {
        zig = zig2nix.outputs.packages.${system}.zig.default.bin;
      };
    in rec {
      # nix build .
      packages.default = env.package {
        src = env.pkgs.lib.cleanSource ./.;
      };

      # nix run .
      apps.default = apps.test;

      # nix run .#build
      apps.build = env.app [] "zig build \"$@\"";

      # nix run .#test
      apps.test = env.app [ env.pkgs.gcc env.pkgs.clang ] ''
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        zig build
        echo "testing zig"
        zig build test -- "$@"
        echo "testing gcc"
        gcc src/test.c zig-out/lib/libbudoux.a -o "$tmpdir/test"
        "$tmpdir/test"
        echo "testing clang"
        clang src/test.c zig-out/lib/libbudoux.a -o "$tmpdir/test"
        "$tmpdir/test"
      '';

      # nix run .#docs
      apps.docs = env.app [] "zig build docs -- \"$@\"";

      # nix run .#deps
      apps.deps = env.showExternalDeps;

      # nix run .#zon2json
      apps.zon2json = env.app [env.zon2json] "zon2json \"$@\"";

      # nix run .#zon2json-lock
      apps.zon2json-lock = env.app [env.zon2json-lock] "zon2json-lock \"$@\"";

      # nix run .#zon2nix
      apps.zon2nix = env.app [env.zon2nix] "zon2nix \"$@\"";

      # nix develop
      devShells.default = env.mkShell {};

      # nix run .#readme
      apps.readme = let
        project = "zig-budoux";
      in env.app [] (builtins.replaceStrings ["`"] ["\\`"] ''
      cat <<EOF
      # ${project}

      [Budoux](https://github.com/google/budoux) for Zig (and C)

      ---

      [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

      Project is tested on zig version $(zig version)

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
      EOF
      '');
    }));
}
