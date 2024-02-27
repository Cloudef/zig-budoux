#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {} *BudouxModel;

typedef struct {
    const BudouxModel *model;
    const char *bytes;
    size_t i;
    size_t unicode_index;
    size_t history[3];
} BudouxChunkIterator;

enum BudouxPrebuiltModel {
    budoux_model_ja,
    budoux_model_ja_knbc,
    budoux_model_th,
    budoux_model_zh_hans,
    budoux_model_zh_hant,
};

BudouxModel budoux_init_from_json(const char *bytes);
BudouxModel budoux_init(enum BudouxPrebuiltModel model);
void budoux_deinit(BudouxModel model);

typedef struct {
    size_t begin;
    size_t end;
} BudouxChunk;

/// Returns `BudouxChunkIterator`, `sentence` must be a valid utf8 string, it is not checked
/// Caller owns the `sentence` memory, and the memory must be valid for the duration of `BudouxChunkIterator` use
BudouxChunkIterator budoux_iterator_init(BudouxModel model, const char *sentence);

/// Returns the next chunk as a `Chunk` containing the `begin` and `end` range
/// Final chunk will be a `Chunk` with `begin` and `end` set to 0
BudouxChunk budoux_iterator_next(BudouxChunkIterator *iterator);

#ifdef __cplusplus
}
#endif
