# Use the official Kubeflow Scipy image v1.10.0
FROM ghcr.io/kubeflow/kubeflow/notebook-servers/jupyter-scipy:v1.10.0

USER root

# 1. Create the system-wide configuration directory
RUN mkdir -p /etc/jupyter/jupyter_server_config.d/

# 2. Create the configuration file
# This targets the Server, Lab, and Session managers to prevent auto-spawning
RUN echo "c.SessionManager.database_filepath = ':memory:'" > /etc/jupyter/jupyter_server_config.d/manual_kernel.py && \
    echo "c.LabServerApp.notebook_starts_kernel = False" >> /etc/jupyter/jupyter_server_config.d/manual_kernel.py && \
    echo "c.ServerApp.notebook_starts_kernel = False" >> /etc/jupyter/jupyter_server_config.d/manual_kernel.py && \
    echo "c.MappingKernelManager.default_kernel_name = ''" >> /etc/jupyter/jupyter_server_config.d/manual_kernel.py && \
    echo "c.LabApp.default_workspace_clean = True" >> /etc/jupyter/jupyter_server_config.d/manual_kernel.py

# 3. Fix permissions for the configuration directory
RUN chown -R jovyan:users /etc/jupyter/jupyter_server_config.d/

# 4. Optional: Set Environment Variables as a secondary fallback
ENV JUPYTER_LAB_SERVER_APP_NOTEBOOK_STARTS_KERNEL=False
ENV JUPYTER_SERVER_APP_NOTEBOOK_STARTS_KERNEL=False

# Switch back to the non-root user
USER jovyan

# Standard entrypoint for Kubeflow Notebooks
WORKDIR /home/jovyan