# Contributing to Neoverse Optimization Benchmarking Tutorial

We welcome contributions to improve this tutorial! Whether you're fixing bugs, adding new optimizations, or improving documentation, your help is appreciated.

## How to Contribute

### 1. Reporting Issues
- Use the GitHub issue tracker to report bugs or suggest improvements
- Include your system information (Neoverse processor type, OS version)
- Provide steps to reproduce any issues
- Include performance measurements when relevant

### 2. Adding New Optimizations
When adding new optimization techniques:

- **Document the optimization**: Explain what it does and when to use it
- **Provide before/after code**: Show unoptimized and optimized versions
- **Include performance measurements**: Demonstrate the improvement with real data
- **Test across processors**: Verify compatibility with different Neoverse types
- **Update the README**: Add the optimization to the appropriate category

### 3. Code Guidelines

#### C/C++ Code
- Use consistent formatting (4 spaces, no tabs)
- Include comprehensive comments explaining optimization techniques
- Provide both scalar and vectorized versions where applicable
- Use meaningful variable names
- Include error handling for system calls

#### Markdown Documentation
- Use clear, concise language
- Include code examples for all concepts
- Provide performance tables with real measurements
- Use consistent formatting for code blocks and tables

### 4. Testing Requirements

Before submitting a pull request:

1. **Test on multiple Neoverse processors** (if available)
2. **Verify performance improvements** with actual measurements
3. **Check compatibility** with different compiler versions
4. **Validate documentation** for clarity and accuracy
5. **Run existing benchmarks** to ensure no regressions

### 5. Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-optimization`)
3. Make your changes following the guidelines above
4. Test thoroughly on Neoverse hardware
5. Update documentation as needed
6. Submit a pull request with:
   - Clear description of changes
   - Performance measurements
   - Testing details

### 6. Optimization Categories

When adding optimizations, categorize them appropriately:

- **Compiler Optimizations**: Build flags, LTO, PGO
- **SIMD Optimizations**: NEON, SVE, intrinsics
- **Memory Optimizations**: Cache blocking, prefetching, alignment
- **Concurrency Optimizations**: Threading, atomics, synchronization
- **System Optimizations**: OS tuning, NUMA, power management

### 7. Performance Measurement Standards

All performance claims must be backed by measurements:

- Use consistent test methodology
- Report hardware specifications
- Include multiple runs for statistical significance
- Provide both absolute and relative improvements
- Test with realistic workload sizes

### 8. Documentation Standards

- Start each section with a clear overview
- Provide practical examples users can run
- Include troubleshooting sections
- Link to relevant ARM documentation
- Use tables for performance comparisons

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/your-org/arm_benchmarking.git
cd arm_benchmarking
```

2. Install dependencies:
```bash
./scripts/install-deps.sh
```

3. Set up development environment:
```bash
# Create development branch
git checkout -b feature/your-feature-name

# Make changes and test
# ...

# Commit with descriptive message
git commit -m "Add SVE2 matrix multiplication optimization

- Implement SVE2 intrinsics for matrix multiplication
- Add performance comparison with NEON version
- Include compatibility detection for SVE2 hardware
- Performance improvement: 2.3x over NEON on V2 processors"
```

## Code Review Process

All contributions go through code review:

1. **Technical Review**: Verify correctness and performance
2. **Documentation Review**: Ensure clarity and completeness
3. **Testing Review**: Confirm adequate testing coverage
4. **Compatibility Review**: Check across different Neoverse processors

## Questions?

- Open an issue for questions about contributing
- Check existing issues and pull requests for similar work
- Reach out to maintainers for guidance on large changes

Thank you for contributing to the Neoverse optimization community!
