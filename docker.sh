docker run -d \
  --name pg17-vector \
  -p 5432:5432 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=123456 \
  -v /data/pg17-vector:/var/lib/postgresql/data \
  pgvector/pgvector:pg17