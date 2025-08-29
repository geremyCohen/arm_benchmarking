CC = gcc
CFLAGS = -O0 -g -Wall
TARGET = baseline_matrix
SRC = src/baseline_matrix.c

# Baseline (unoptimized) build
baseline: $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) -lm

# Clean build artifacts
clean:
	rm -f $(TARGET)

.PHONY: baseline clean
