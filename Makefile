CC = gcc
SRC = src/baseline_matrix.c
OPT_SRC = src/optimized_matrix.c

# Baseline (unoptimized) build
baseline:
	$(CC) -O0 -g -Wall -o baseline_matrix $(SRC) -lm

# Compiler optimization levels
opt-O1:
	$(CC) -O1 -Wall -o optimized_O1 $(OPT_SRC) -lm

opt-O2:
	$(CC) -O2 -Wall -o optimized_O2 $(OPT_SRC) -lm

opt-O3:
	$(CC) -O3 -Wall -o optimized_O3 $(OPT_SRC) -lm

# Clean build artifacts
clean:
	rm -f baseline_matrix optimized_O1 optimized_O2 optimized_O3 optimized_neoverse

.PHONY: baseline opt-O1 opt-O2 opt-O3 clean
