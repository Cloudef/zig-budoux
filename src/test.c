#include "../include/budoux.h"
#include <stdio.h>
#include <assert.h>

int main() {
  BudouxModel model = budoux_init(budoux_model_ja);
  const char *sentence = "今日は天気です。";
  BudouxChunkIterator iter = budoux_iterator_init(model, sentence);
  BudouxChunk chunk;
  chunk = budoux_iterator_next(iter); // 今日は
  printf("%.*s\n", (int)(chunk.end - chunk.begin), sentence + chunk.begin);
  assert(chunk.begin == 0 && chunk.end == 9);
  chunk = budoux_iterator_next(iter); // 天気です。
  printf("%.*s\n", (int)(chunk.end - chunk.begin), sentence + chunk.begin);
  assert(chunk.begin == 9 && chunk.end == 24);
  budoux_iterator_deinit(iter);
  budoux_deinit(model);
  return 0;
}
