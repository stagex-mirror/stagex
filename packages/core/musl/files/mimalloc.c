/*
 * Copyright (c) 2022, 2023, Chimera Linux contributors
 * SPDX-License-Identifier: MIT
 */

#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <sys/mman.h>

#include "mimalloc.h"

#define MIMALLOC_PAGE_SIZE 4096

void *malloc(size_t size) {
	return mi_malloc(size);
}

void free(void *ptr) {
	mi_free(ptr);
}

void *realloc(void *ptr, size_t size) {
	return mi_realloc(ptr, size);
}

void *calloc(size_t nmemb, size_t size) {
	return mi_calloc(nmemb, size);
}

void *aligned_alloc(size_t alignment, size_t size) {
	return mi_memalign(alignment, size);
}

void *memalign(size_t alignment, size_t size) {
	return mi_memalign(alignment, size);
}

int posix_memalign(void **memptr, size_t alignment, size_t size) {
	return mi_posix_memalign(memptr, alignment, size);
}

void *valloc(size_t size) {
	return mi_memalign(MIMALLOC_PAGE_SIZE, size);
}

void *pvalloc(size_t size) {
	size_t pages = (size + MIMALLOC_PAGE_SIZE - 1) / MIMALLOC_PAGE_SIZE;
	return mi_memalign(MIMALLOC_PAGE_SIZE, pages * MIMALLOC_PAGE_SIZE);
}

void *reallocarray(void *ptr, size_t nmemb, size_t size) {
	return mi_reallocarray(ptr, nmemb, size);
}

char *strdup(const char *s) {
	return mi_strdup(s);
}

char *strndup(const char *s, size_t n) {
	return mi_strndup(s, n);
}

size_t malloc_usable_size(void *ptr) {
	return mi_usable_size(ptr);
}

int malloc_trim(size_t pad) {
	return 0;
}

void malloc_stats(void) {
}

int mallopt(int num, int val) {
	return 1;
}
