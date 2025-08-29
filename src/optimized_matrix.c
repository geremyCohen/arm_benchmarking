#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

// Optimized matrix multiplication (same algorithm, different compilation)
void matrix_multiply_optimized(float *A, float *B, float *C, int N) {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            float sum = 0.0f;
            for (int k = 0; k < N; k++) {
                sum += A[i * N + k] * B[k * N + j];
            }
            C[i * N + j] = sum;
        }
    }
}

double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

int main(int argc, char *argv[]) {
    int N = 512; // Default size
    
    if (argc > 1) {
        if (strcmp(argv[1], "micro") == 0) N = 64;
        else if (strcmp(argv[1], "small") == 0) N = 512;
        else if (strcmp(argv[1], "medium") == 0) N = 2048;
        else if (strcmp(argv[1], "large") == 0) N = 8192;
    }
    
    printf("=== Optimized Matrix Multiplication ===\n");
    printf("Size: %dx%d (%s)\n", N, N, argc > 1 ? argv[1] : "small");
    printf("Memory: %.1f MB\n", (3.0 * N * N * sizeof(float)) / (1024 * 1024));
    
    // Allocate matrices
    float *A = malloc(N * N * sizeof(float));
    float *B = malloc(N * N * sizeof(float));
    float *C = malloc(N * N * sizeof(float));
    
    // Initialize with simple values
    for (int i = 0; i < N * N; i++) {
        A[i] = 1.0f;
        B[i] = 2.0f;
        C[i] = 0.0f;
    }
    
    // Warm up
    matrix_multiply_optimized(A, B, C, N);
    
    // Benchmark
    double start = get_time();
    matrix_multiply_optimized(A, B, C, N);
    double end = get_time();
    
    double time_sec = end - start;
    double gflops = (2.0 * N * N * N) / (time_sec * 1e9);
    
    printf("Time: %.3f seconds\n", time_sec);
    printf("Performance: %.2f GFLOPS\n", gflops);
    printf("Result check: C[0] = %.1f (expected: %.1f)\n", C[0], (float)N * 2.0f);
    
    free(A);
    free(B);
    free(C);
    
    return 0;
}
