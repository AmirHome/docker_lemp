# Grant permissions for to our scripts to be executable
RUN chmod +x /usr/config/entrypoint.sh
RUN chmod +x /usr/config/configure-db.sh

# Ensure the scripts are copied with the right permissions
COPY --chown=mssql:mssql entrypoint.sh /usr/config/
COPY --chown=mssql:mssql configure-db.sh /usr/config/
COPY --chown=mssql:mssql setup.sql /usr/config/ 