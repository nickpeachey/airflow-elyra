# Custom Jupyter image with Elyra pre-installed
FROM quay.io/jupyter/scipy-notebook:latest

# Switch to root to install packages
USER root

# Install system dependencies including Node.js for JupyterLab builds
RUN apt-get update && apt-get install -y \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Switch back to jovyan user for Python package installation
USER $NB_UID

# Install PySpark first (needs older setuptools)
RUN pip install --no-cache-dir \
    pyspark==3.4.1 \
    boto3==1.34.0

# Install Elyra and dependencies (this will update setuptools)
RUN pip install --no-cache-dir \
    papermill==2.4.0 \
    click==8.1.7 \
    entrypoints==0.4 \
    traitlets==5.9.0 \
    jupyter-packaging==0.12.3 \
    jupyter-server>=2.0.0 \
    && pip install --no-cache-dir "elyra[all]==3.15.0"

# Install Kubernetes client (compatible with newer setuptools)
RUN pip install --no-cache-dir kubernetes==29.0.0

# Build JupyterLab with Elyra extensions
RUN jupyter lab build --dev-build=False --minimize=False

# Verify installation
RUN jupyter server extension list
RUN python -c "import elyra; print('✓ Elyra Python package imported successfully')"
RUN python -c "from elyra.metadata.manager import MetadataManager; print('✓ Elyra MetadataManager imported successfully')"

# Create default runtime configurations directory
RUN mkdir -p /home/jovyan/.local/share/jupyter/metadata/runtimes

# Switch back to root to ensure proper permissions
USER root
RUN fix-permissions /home/jovyan/.local

# Switch back to jovyan user
USER $NB_UID

# Set working directory
WORKDIR /home/jovyan/work

# Default command
CMD ["start-notebook.sh"]
