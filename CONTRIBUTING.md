# Contributing to Oracle 26ai MCP Agentic Workflows

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Getting Started

1. **Fork the repository**
   ```bash
   git clone https://github.com/hvrcharon1/oracle-26ai-mcp-agentic-workflows-typescript.git
   cd oracle-26ai-mcp-agentic-workflows-typescript
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment**
   ```bash
   cp .env.example .env
   # Edit .env with your credentials
   ```

4. **Run tests**
   ```bash
   npm test
   ```

## Development Workflow

1. Create a feature branch
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes
   - Write clear, commented code
   - Follow TypeScript/Java/PL-SQL best practices
   - Add tests for new functionality

3. Test your changes
   ```bash
   npm run build
   npm test
   npm run lint
   ```

4. Commit your changes
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

5. Push and create a pull request
   ```bash
   git push origin feature/your-feature-name
   ```

## Code Style

### TypeScript
- Use TypeScript strict mode
- Follow ESLint configuration
- Use async/await for asynchronous operations
- Add JSDoc comments for public APIs

### Java
- Follow Java naming conventions
- Use Java 17+ features
- Add Javadoc comments
- Handle exceptions properly

### PL/SQL
- Use Oracle naming conventions
- Add comments for complex logic
- Handle exceptions with proper error messages
- Use bind variables to prevent SQL injection

## Documentation

- Update README.md for new features
- Add examples in `/examples` directory
- Document all public APIs
- Update relevant documentation in `/docs`

## Testing

- Write unit tests for new functionality
- Ensure all tests pass before submitting PR
- Add integration tests where appropriate
- Test with Oracle Database 26ai

## Pull Request Process

1. **Update documentation** for any changed functionality
2. **Add tests** for new features
3. **Ensure CI passes** all checks
4. **Request review** from maintainers
5. **Address feedback** promptly

## Commit Message Guidelines

Use conventional commits format:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes
- `refactor:` Code refactoring
- `test:` Test additions or changes
- `chore:` Build process or auxiliary tool changes

Example:
```
feat: add vector search optimization

- Implement HNSW index configuration
- Add performance benchmarks
- Update documentation
```

## Issues

- Use issue templates when available
- Provide clear reproduction steps
- Include environment details
- Add relevant logs or error messages

## Questions?

Feel free to open an issue for:
- Bug reports
- Feature requests
- Documentation improvements
- General questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to making AI agents with Oracle 26ai better!