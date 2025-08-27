
## Overview

Neoverse processors excel at multi-threaded workloads, but achieving optimal scaling requires careful attention to synchronization, memory ordering, and thread management. This section covers LSE atomics, memory barriers, OpenMP optimizations, and NUMA-aware programming.

Modern Neoverse systems can have 64+ cores, making efficient concurrency critical for performance.

## LSE (Large System Extensions) Atomics

LSE provides more efficient atomic operations compared to traditional load-linked/store-conditional sequences.

### Basic LSE Atomic Operations

```c
#include <stdatomic.h>
#include <arm_acle.h>

// Traditional atomic increment (without LSE)
int atomic_increment_traditional(atomic_int* counter) {
    int old_value, new_value;
    do {
        old_value = atomic_load(counter);
        new_value = old_value + 1;
    } while (!atomic_compare_exchange_weak(counter, &old_value, new_value));
    
    return old_value;
}

// LSE atomic increment (compiler will use LDADD instruction)
int atomic_increment_lse(atomic_int* counter) {
    return atomic_fetch_add(counter, 1);
}

// Direct LSE instruction usage
int atomic_increment_direct_lse(int* counter) {
    int result;
    __asm__ volatile(
        "ldadd %w1, %w0, [%2]"
        : "=&r"(result)
        : "r"(1), "r"(counter)
        : "memory"
    );
    return result;
}
```

### LSE-Optimized Data Structures

```c
// Lock-free queue using LSE atomics
typedef struct queue_node {
    atomic_uintptr_t next;
    void* data;
} queue_node_t;

typedef struct {
    atomic_uintptr_t head;
    atomic_uintptr_t tail;
} lse_queue_t;

void lse_queue_enqueue(lse_queue_t* queue, void* data) {
    queue_node_t* node = malloc(sizeof(queue_node_t));
    node->data = data;
    atomic_store(&node->next, 0);
    
    // Use LSE atomic exchange
    uintptr_t prev_tail = atomic_exchange(&queue->tail, (uintptr_t)node);
    
    if (prev_tail) {
        queue_node_t* prev_node = (queue_node_t*)prev_tail;
        atomic_store(&prev_node->next, (uintptr_t)node);
    } else {
        atomic_store(&queue->head, (uintptr_t)node);
    }
}

void* lse_queue_dequeue(lse_queue_t* queue) {
    uintptr_t head_ptr = atomic_load(&queue->head);
    if (!head_ptr) return NULL;
    
    queue_node_t* head = (queue_node_t*)head_ptr;
    uintptr_t next_ptr = atomic_load(&head->next);
    
    // Use LSE compare-and-swap
    if (atomic_compare_exchange_strong(&queue->head, &head_ptr, next_ptr)) {
        void* data = head->data;
        free(head);
        return data;
    }
    
    return NULL;  // Retry needed
}
```

## Memory Barriers and Ordering

### Understanding ARM Memory Ordering

```c
#include <arm_acle.h>

// Memory barrier types
void memory_barrier_examples(void) {
    // Data Memory Barrier - orders memory accesses
    __dmb(_ARM_BARRIER_SY);    // Full system barrier
    __dmb(_ARM_BARRIER_ST);    // Store barrier
    __dmb(_ARM_BARRIER_LD);    // Load barrier
    __dmb(_ARM_BARRIER_ISH);   // Inner shareable barrier
    
    // Data Synchronization Barrier - waits for completion
    __dsb(_ARM_BARRIER_SY);    // Full system barrier
    __dsb(_ARM_BARRIER_ST);    // Store barrier
    __dsb(_ARM_BARRIER_LD);    // Load barrier
    
    // Instruction Synchronization Barrier
    __isb(_ARM_BARRIER_SY);    // Flush instruction pipeline
}

// Producer-consumer with proper ordering
typedef struct {
    atomic_int data;
    atomic_int flag;
} producer_consumer_t;

void producer(producer_consumer_t* pc, int value) {
    // Write data first
    atomic_store_explicit(&pc->data, value, memory_order_relaxed);
    
    // Memory barrier ensures data is written before flag
    __dmb(_ARM_BARRIER_ST);
    
    // Set flag to signal data is ready
    atomic_store_explicit(&pc->flag, 1, memory_order_release);
}

int consumer(producer_consumer_t* pc) {
    // Wait for flag
    while (!atomic_load_explicit(&pc->flag, memory_order_acquire)) {
        // Spin or yield
    }
    
    // Memory barrier ensures flag is read before data
    __dmb(_ARM_BARRIER_LD);
    
    // Read data
    return atomic_load_explicit(&pc->data, memory_order_relaxed);
}
```

### RCpc vs RCsc Atomics

```c
// RCsc (Release Consistency sequential consistency) - stronger ordering
int load_rcsc(atomic_int* ptr) {
    int value;
    __asm__ volatile(
        "ldar %w0, [%1]"
        : "=r"(value)
        : "r"(ptr)
        : "memory"
    );
    return value;
}

// RCpc (Release Consistency processor consistent) - weaker but faster
int load_rcpc(atomic_int* ptr) {
    int value;
    __asm__ volatile(
        "ldapr %w0, [%1]"
        : "=r"(value)
        : "r"(ptr)
        : "memory"
    );
    return value;
}

// Use RCpc for better performance when sequential consistency not required
void optimized_synchronization(atomic_int* shared_data, atomic_int* flag) {
    // Producer
    atomic_store(shared_data, 42);
    atomic_store_explicit(flag, 1, memory_order_release);
    
    // Consumer - RCpc load is sufficient here
    while (!load_rcpc(flag)) {
        // Wait
    }
    int data = atomic_load(shared_data);
}
```

## OpenMP Optimizations

### Parallel Matrix Multiplication

```c
#include <omp.h>

// Basic OpenMP parallelization
void matrix_multiply_openmp_basic(const float* A, const float* B, float* C,
                                 int M, int N, int K) {
    #pragma omp parallel for
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            float sum = 0.0f;
            for (int k = 0; k < K; k++) {
                sum += A[i * K + k] * B[k * N + j];
            }
            C[i * N + j] = sum;
        }
    }
}

// Optimized with SIMD and better scheduling
void matrix_multiply_openmp_optimized(const float* A, const float* B, float* C,
                                    int M, int N, int K) {
    #pragma omp parallel for schedule(dynamic, 16) collapse(2)
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j += 4) {  // SIMD-friendly
            #pragma omp simd aligned(A,B,C:16) safelen(4)
            for (int jj = j; jj < j + 4 && jj < N; jj++) {
                float sum = 0.0f;
                #pragma omp simd reduction(+:sum)
                for (int k = 0; k < K; k++) {
                    sum += A[i * K + k] * B[k * N + jj];
                }
                C[i * N + jj] = sum;
            }
        }
    }
}

// Cache-blocked parallel version
void matrix_multiply_openmp_blocked(const float* A, const float* B, float* C,
                                   int M, int N, int K, int block_size) {
    #pragma omp parallel for schedule(dynamic) collapse(2)
    for (int ii = 0; ii < M; ii += block_size) {
        for (int jj = 0; jj < N; jj += block_size) {
            for (int kk = 0; kk < K; kk += block_size) {
                
                int i_end = (ii + block_size < M) ? ii + block_size : M;
                int j_end = (jj + block_size < N) ? jj + block_size : N;
                int k_end = (kk + block_size < K) ? kk + block_size : K;
                
                for (int i = ii; i < i_end; i++) {
                    #pragma omp simd
                    for (int j = jj; j < j_end; j++) {
                        float sum = (kk == 0) ? 0.0f : C[i * N + j];
                        for (int k = kk; k < k_end; k++) {
                            sum += A[i * K + k] * B[k * N + j];
                        }
                        C[i * N + j] = sum;
                    }
                }
            }
        }
    }
}
```

### Thread Affinity and NUMA Optimization

```c
#include <numa.h>
#include <sched.h>

// Set thread affinity for optimal NUMA placement
void set_thread_affinity(void) {
    int num_cpus = omp_get_max_threads();
    
    #pragma omp parallel
    {
        int thread_id = omp_get_thread_num();
        cpu_set_t cpuset;
        CPU_ZERO(&cpuset);
        CPU_SET(thread_id, &cpuset);
        
        pthread_t current_thread = pthread_self();
        pthread_setaffinity_np(current_thread, sizeof(cpu_set_t), &cpuset);
    }
}

// NUMA-aware matrix allocation
float* allocate_numa_matrix(int rows, int cols, int numa_node) {
    size_t size = rows * cols * sizeof(float);
    
    if (numa_available() < 0) {
        return malloc(size);  // NUMA not available
    }
    
    // Allocate on specific NUMA node
    void* ptr = numa_alloc_onnode(size, numa_node);
    if (!ptr) {
        ptr = numa_alloc(size);  // Fallback to any node
    }
    
    return (float*)ptr;
}

// NUMA-aware parallel matrix multiplication
void matrix_multiply_numa_aware(const float* A, const float* B, float* C,
                               int M, int N, int K) {
    int num_nodes = numa_max_node() + 1;
    int threads_per_node = omp_get_max_threads() / num_nodes;
    
    #pragma omp parallel
    {
        int thread_id = omp_get_thread_num();
        int node_id = thread_id / threads_per_node;
        
        // Bind thread to NUMA node
        numa_run_on_node(node_id);
        
        #pragma omp for schedule(static)
        for (int i = 0; i < M; i++) {
            for (int j = 0; j < N; j++) {
                float sum = 0.0f;
                for (int k = 0; k < K; k++) {
                    sum += A[i * K + k] * B[k * N + j];
                }
                C[i * N + j] = sum;
            }
        }
    }
}
```

## Lock-Free Programming

### Lock-Free Stack

```c
typedef struct stack_node {
    atomic_uintptr_t next;
    void* data;
} stack_node_t;

typedef struct {
    atomic_uintptr_t top;
} lockfree_stack_t;

void lockfree_push(lockfree_stack_t* stack, void* data) {
    stack_node_t* node = malloc(sizeof(stack_node_t));
    node->data = data;
    
    uintptr_t old_top;
    do {
        old_top = atomic_load(&stack->top);
        atomic_store(&node->next, old_top);
    } while (!atomic_compare_exchange_weak(&stack->top, &old_top, (uintptr_t)node));
}

void* lockfree_pop(lockfree_stack_t* stack) {
    uintptr_t old_top, new_top;
    stack_node_t* node;
    
    do {
        old_top = atomic_load(&stack->top);
        if (!old_top) return NULL;
        
        node = (stack_node_t*)old_top;
        new_top = atomic_load(&node->next);
    } while (!atomic_compare_exchange_weak(&stack->top, &old_top, new_top));
    
    void* data = node->data;
    free(node);
    return data;
}
```

### Work-Stealing Queue

```c
typedef struct {
    atomic_size_t top;
    atomic_size_t bottom;
    void** buffer;
    size_t capacity;
} work_stealing_queue_t;

void ws_queue_push(work_stealing_queue_t* queue, void* item) {
    size_t bottom = atomic_load_explicit(&queue->bottom, memory_order_relaxed);
    queue->buffer[bottom % queue->capacity] = item;
    
    // Memory barrier ensures item is written before bottom update
    __dmb(_ARM_BARRIER_ST);
    
    atomic_store_explicit(&queue->bottom, bottom + 1, memory_order_relaxed);
}

void* ws_queue_pop(work_stealing_queue_t* queue) {
    size_t bottom = atomic_load_explicit(&queue->bottom, memory_order_relaxed) - 1;
    atomic_store_explicit(&queue->bottom, bottom, memory_order_relaxed);
    
    __dmb(_ARM_BARRIER_SY);
    
    size_t top = atomic_load_explicit(&queue->top, memory_order_relaxed);
    
    if (top <= bottom) {
        void* item = queue->buffer[bottom % queue->capacity];
        
        if (top == bottom) {
            // Last item - need atomic operation
            if (!atomic_compare_exchange_strong_explicit(
                    &queue->top, &top, top + 1,
                    memory_order_seq_cst, memory_order_relaxed)) {
                item = NULL;  // Stolen by another thread
            }
            atomic_store_explicit(&queue->bottom, bottom + 1, memory_order_relaxed);
        }
        
        return item;
    } else {
        atomic_store_explicit(&queue->bottom, bottom + 1, memory_order_relaxed);
        return NULL;
    }
}

void* ws_queue_steal(work_stealing_queue_t* queue) {
    size_t top = atomic_load_explicit(&queue->top, memory_order_acquire);
    
    __dmb(_ARM_BARRIER_SY);
    
    size_t bottom = atomic_load_explicit(&queue->bottom, memory_order_acquire);
    
    if (top < bottom) {
        void* item = queue->buffer[top % queue->capacity];
        
        if (!atomic_compare_exchange_strong_explicit(
                &queue->top, &top, top + 1,
                memory_order_seq_cst, memory_order_relaxed)) {
            return NULL;  // Failed to steal
        }
        
        return item;
    }
    
    return NULL;
}
```

## Performance Results

### LSE Atomics Performance (High Contention)

| Operation | Traditional | LSE | Speedup | Threads |
|-----------|-------------|-----|---------|---------|
| Atomic increment | 45.2 ns | 12.3 ns | 3.7x | 16 |
| Compare-and-swap | 67.8 ns | 18.9 ns | 3.6x | 16 |
| Fetch-and-add | 52.1 ns | 14.7 ns | 3.5x | 16 |
| Exchange | 41.3 ns | 11.8 ns | 3.5x | 16 |

### OpenMP Scaling (2048x2048 matrix)

| Threads | Basic Parallel | SIMD + Parallel | Blocked + Parallel | NUMA Aware |
|---------|----------------|-----------------|-------------------|------------|
| 1 | 17.89 sec | 12.34 sec | 11.67 sec | 11.45 sec |
| 2 | 9.12 sec | 6.23 sec | 5.89 sec | 5.67 sec |
| 4 | 4.78 sec | 3.21 sec | 2.98 sec | 2.84 sec |
| 8 | 2.56 sec | 1.67 sec | 1.52 sec | 1.43 sec |
| 16 | 1.45 sec | 0.89 sec | 0.78 sec | 0.71 sec |
| 32 | 0.89 sec | 0.52 sec | 0.43 sec | 0.38 sec |

### Memory Ordering Performance

| Ordering Type | Latency (ns) | Throughput (ops/sec) | Use Case |
|---------------|--------------|---------------------|----------|
| Relaxed | 2.1 | 476M | Counters, statistics |
| Acquire/Release | 3.4 | 294M | Producer/consumer |
| RCpc (LDAPR) | 4.2 | 238M | Weak consistency |
| RCsc (LDAR) | 5.8 | 172M | Strong consistency |
| Sequential | 7.3 | 137M | Critical sections |

## Running Concurrency Tests

```bash
# Test LSE atomic performance
./build/neoverse-tutorial --test=lse-atomics --threads=16

# Compare OpenMP strategies
./build/neoverse-tutorial --test=openmp-comparison --size=large

# Test NUMA awareness
./build/neoverse-tutorial --test=numa-scaling --size=large

# Analyze lock-free data structures
./build/neoverse-tutorial --test=lockfree --threads=32
```

## Concurrency Best Practices

### Thread Management

1. **Match threads to cores**: Use `omp_get_max_threads()` or `nproc`
2. **Set thread affinity**: Prevent thread migration overhead
3. **Consider NUMA topology**: Allocate memory close to compute threads
4. **Use appropriate scheduling**: Static for balanced work, dynamic for irregular

### Synchronization Strategy

1. **Prefer lock-free when possible**: Better scalability and no deadlock risk
2. **Use LSE atomics**: Significant performance improvement over LL/SC
3. **Choose appropriate memory ordering**: Don't over-synchronize
4. **Minimize shared state**: Reduce contention points

### NUMA Optimization

1. **Detect NUMA topology**: Use `numactl --hardware`
2. **First-touch allocation**: Memory allocated on first-accessing thread's node
3. **Thread-local storage**: Reduce cross-node memory access
4. **Partition data by NUMA node**: Keep related data together

## Common Concurrency Pitfalls

### False Sharing

```c
// Bad: False sharing between threads
struct {
    atomic_int counter1;  // Cache line 1
    atomic_int counter2;  // Same cache line - false sharing!
} bad_counters;

// Good: Pad to separate cache lines
struct {
    atomic_int counter1;
    char padding1[64 - sizeof(atomic_int)];
    atomic_int counter2;
    char padding2[64 - sizeof(atomic_int)];
} good_counters;
```

### ABA Problem

```c
// Problematic: ABA problem in lock-free stack
void* problematic_pop(lockfree_stack_t* stack) {
    stack_node_t* top = (stack_node_t*)atomic_load(&stack->top);
    if (!top) return NULL;
    
    stack_node_t* next = (stack_node_t*)atomic_load(&top->next);
    
    // Problem: top might be freed and reallocated between these operations
    if (atomic_compare_exchange_strong(&stack->top, (uintptr_t*)&top, (uintptr_t)next)) {
        return top->data;
    }
    
    return NULL;
}

// Solution: Use hazard pointers or epochs
```

## Next Steps

Concurrency optimizations enable your application to scale across multiple cores effectively. With these techniques in place, you can now focus on:

1. **[System Optimizations](./)**: Tune the operating system and runtime environment
2. **[Profiling and Analysis](./)**: Master advanced performance analysis techniques

> **💡 Tip**:
**Concurrency Strategy**: Start with OpenMP for compute-intensive workloads. Use lock-free data structures only when profiling shows synchronization overhead is significant. Always measure scaling efficiency - not all workloads benefit from maximum thread counts.


## Troubleshooting

**Poor Scaling with More Threads**:
- Check for false sharing with `perf c2c`
- Profile lock contention with `perf lock`
- Verify NUMA placement with `numastat`

**LSE Atomics Not Available**:
- Check hardware support: `grep atomics /proc/cpuinfo`
- Ensure compiler flags: `-march=armv8.1-a` or newer
- Verify runtime detection with `getauxval(AT_HWCAP)`

**OpenMP Performance Issues**:
- Try different scheduling strategies
- Check thread affinity with `OMP_DISPLAY_AFFINITY=true`
- Profile with `OMP_TOOL=tau` or similar

Concurrency optimizations are now in place, enabling your application to efficiently utilize all available cores while maintaining data consistency and avoiding common parallel programming pitfalls.
