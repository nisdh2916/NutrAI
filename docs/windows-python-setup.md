# Windows Python setup notes

## chromadb install failure on Python 3.12

### Symptom

Running the backend dependency install fails while building `chroma-hnswlib`:

```powershell
python -m pip install -r server\requirements.txt
```

Typical error:

```text
Microsoft Visual C++ 14.0 or greater is required
```

### Cause

The project currently pins `chromadb==1.0.4`. On Windows with Python 3.12,
that dependency can try to build `chroma-hnswlib==0.7.6` from source. Without
Microsoft C++ Build Tools, the install stops before the RAG server can import
`chromadb`.

### Recommended setup

Use Python 3.11 for the server/RAG virtual environment:

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\activate
python -m pip install -r server\requirements.txt
```

### Alternative

If Python 3.12 must be used, install Microsoft C++ Build Tools first, then run
the dependency install again.
