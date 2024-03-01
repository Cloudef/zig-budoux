#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef unsigned long int budoux_size_t;

typedef struct {} *BudouxModel;

typedef struct {
    const BudouxModel *model;
    const char *bytes;
    budoux_size_t bytes_len;
    budoux_size_t i;
    budoux_size_t i_codepoint;
    budoux_size_t history[3];
} BudouxChunkIterator;

enum BudouxPrebuiltModel {
    budoux_model_ja,
    budoux_model_ja_knbc,
    budoux_model_th,
    budoux_model_zh_hans,
    budoux_model_zh_hant,
};

BudouxModel budoux_init_from_json(const char *bytes, budoux_size_t len);
BudouxModel budoux_init_from_zlib_json(const char *bytes, budoux_size_t len);
BudouxModel budoux_init(enum BudouxPrebuiltModel model);
void budoux_deinit(BudouxModel model);

typedef struct {
    budoux_size_t begin;
    budoux_size_t end;
} BudouxChunk;

/// Returns `BudouxChunkIterator`, `sentence` must be a valid utf8 string, it is not checked
/// Caller owns the `sentence` memory, and the memory must be valid for the duration of `BudouxChunkIterator` use
BudouxChunkIterator budoux_iterator_init(BudouxModel model, const char *sentence);

/// Returns `BudouxChunkIterator`, from a slice of `sentence` must be a valid utf8 string, it is not checked
/// Caller owns the `sentence` memory, and the memory must be valid for the duration of `BudouxChunkIterator` use
BudouxChunkIterator budoux_iterator_init_from_slice(BudouxModel model, const char *sentence, budoux_size_t len);

/// Returns the next chunk as a `Chunk` containing the `begin` and `end` range
/// Final chunk will be a `Chunk` with `begin` and `end` set to 0
BudouxChunk budoux_iterator_next(BudouxChunkIterator *iterator);

#ifdef __cplusplus
}
#endif
