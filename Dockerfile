FROM apache/airflow:3.3.2

COPY requirements.txt /requirements.txt

# Keep Airflow fixed when adding dependencies to the local development image.
RUN pip install --no-cache-dir "apache-airflow==3.3.2" -r /requirements.txt
