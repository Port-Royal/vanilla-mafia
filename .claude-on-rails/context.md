# ClaudeOnRails Context

This project uses ClaudeOnRails with a swarm of specialized agents for Rails development.

## Project Information
- **Rails Version**: 8.1.2
- **Ruby Version**: 4.0.1
- **Project Type**: Full-stack Rails
- **Test Framework**: RSpec
- **Turbo/Stimulus**: Enabled

## Swarm Configuration

The claude-swarm.yml file defines specialized agents for different aspects of Rails development:
- Each agent has specific expertise and works in designated directories
- Agents collaborate to implement features across all layers
- The architect agent coordinates the team

## Development Guidelines

When working on this project:
- Follow Rails conventions and best practices
- Write tests for all new functionality
- Use strong parameters in controllers
- Keep models focused with single responsibilities
- Extract complex business logic to service objects
- Ensure proper database indexing for foreign keys and queries

## Mutation Testing

This project uses [mutant](https://github.com/mbj/mutant) for mutation testing to verify test quality.

### Running Mutant
- **Single class**: `bundle exec mutant run -- 'YourClass'`
- **Single method**: `bundle exec mutant run -- 'YourClass#method_name'`
- **After writing tests**: Always run mutant against the class under test to verify test quality

### Workflow
1. Write or modify code
2. Write RSpec tests that pass
3. Run mutant against the changed class(es) to check for surviving mutants
4. If mutants survive, add or strengthen assertions to kill them
5. Aim for zero surviving mutants on all new/modified code

### Common Surviving Mutants to Watch For
- Missing boundary/edge case assertions (e.g., `>` vs `>=`)
- Untested return values
- Conditional branches without dedicated test cases
- Method calls whose removal doesn't break any test