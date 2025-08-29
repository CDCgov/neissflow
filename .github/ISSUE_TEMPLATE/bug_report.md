---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug, reproduced, needs-investigation
assignees: ''

---

## **Describe the Bug**
A clear and concise description of the issue, including the affected tool, pipeline, or script.

## **To Reproduce**
Steps to reproduce the behavior, including:
1. **Command(s) run**: Provide the exact command(s) used.
2. **Input files**: Describe or attach relevant input files (e.g., FASTQ, FASTA).
3. **Environment**:
   - Conda/Mamba environment (`conda list` or `mamba list`)
   - Singularity/Docker image version (if applicable)
   - Git commit hash (`git rev-parse HEAD` if using a repository)
4. **Error message**: Copy and paste the exact error message or traceback.

## **Expected Behavior**
A clear and concise description of what should happen.

## **Screenshots (if applicable)**
If applicable, attach screenshots, plots, or error outputs.

## **Logs & Debug Info**
- Attach relevant log files (`.log`, `.err`, `.out`). To save logs ` <command> 2>&1 | tee -a log.txt`
- Run the script with `--verbose` or `--debug` (if applicable) and attach the output.

## Possible fixes
(If you can, link to the line of code that might be responsible for the problem)

## **Additional Context**
Any other relevant details, such as links to related issues or discussions.
