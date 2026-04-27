# DefectDojo Setup Evidence

- Date captured: 2026-04-13
- DefectDojo source cloned to `labs/lab10/setup/django-DefectDojo`
- Local stack started with `docker compose up -d`
- Core services confirmed running:
  - `django-defectdojo-nginx-1`
  - `django-defectdojo-uwsgi-1`
  - `django-defectdojo-postgres-1`
  - `django-defectdojo-valkey-1`
  - `django-defectdojo-celerybeat-1`
  - `django-defectdojo-celeryworker-1`
- Product context created via import API:
  - Product Type: `Engineering`
  - Product: `Juice Shop`
  - Engagement: `Labs Security Testing`
- Admin API token was generated inside the container for scripted imports and exports.
