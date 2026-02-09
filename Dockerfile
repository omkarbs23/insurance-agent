# Use official Python runtime as base image
FROM python:3.12-slim

# Ensure stdout/stderr are not buffered
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libopenblas-dev \
    liblapack-dev \
    gfortran \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user and set permissions
RUN useradd -ms /bin/bash appuser

# Set the working directory in the container
WORKDIR /home/appuser/app

# Copy requirements first for better caching
COPY requirements.txt .

# Create a virtual environment and install dependencies as root, then fix permissions
RUN python3 -m venv venv && \
    venv/bin/pip install --upgrade pip && \
    venv/bin/pip install --no-cache-dir -r requirements.txt && \
    chown -R appuser:appuser venv

# Copy the rest of the application code and set ownership
COPY --chown=appuser:appuser . /home/appuser/app

# Create necessary directories as root, then change ownership
RUN mkdir -p logs data chroma_db && \
    chown -R appuser:appuser /home/appuser/app

# Switch to non-root user AFTER creating directories
USER appuser

# Expose Streamlit port
EXPOSE 8501

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s \
    CMD curl --fail http://127.0.0.1:8501/_stcore/health || exit 1

# Set environment variables
ENV STREAMLIT_SERVER_PORT=8501
ENV STREAMLIT_SERVER_ADDRESS=0.0.0.0
ENV STREAMLIT_SERVER_HEADLESS=true
ENV STREAMLIT_BROWSER_GATHER_USAGE_STATS=false

# Run Streamlit app using relative venv path
CMD ["venv/bin/streamlit", "run", "app/main.py", "--server.port=8501", "--server.address=0.0.0.0"]
