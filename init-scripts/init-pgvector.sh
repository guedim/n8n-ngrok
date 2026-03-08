#!/bin/bash
# Script de inicialización para pgvector con variables de entorno
# Este archivo debe colocarse en ./init-scripts/ y ser ejecutable

set -e

# Usar variables de entorno de PostgreSQL
DB_NAME=${POSTGRES_DB}
DB_USER=${POSTGRES_USER}

echo "Inicializando pgvector para base de datos: $DB_NAME con usuario: $DB_USER"

# Ejecutar comandos SQL usando psql
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_NAME" <<-EOSQL
    -- Crear la extensión pgvector
    CREATE EXTENSION IF NOT EXISTS vector;
    
    -- Crear una tabla de ejemplo para vectores
    CREATE TABLE IF NOT EXISTS embeddings (
        id SERIAL PRIMARY KEY,
        content TEXT NOT NULL,
        vector vector(1536), -- Dimensión típica para OpenAI embeddings
        metadata JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Crear índice para búsquedas vectoriales eficientes
    CREATE INDEX IF NOT EXISTS embeddings_vector_idx ON embeddings 
        USING ivfflat (vector vector_cosine_ops) WITH (lists = 100);
    
    -- Crear función para búsqueda de similaridad
    CREATE OR REPLACE FUNCTION search_similar_vectors(
        query_vector vector(1536),
        match_threshold float DEFAULT 0.8,
        match_count int DEFAULT 10
    )
    RETURNS TABLE (
        id integer,
        content text,
        similarity float,
        metadata jsonb
    )
    LANGUAGE plpgsql
    AS \$\$
    BEGIN
        RETURN QUERY
        SELECT 
            embeddings.id,
            embeddings.content,
            1 - (embeddings.vector <=> query_vector) as similarity,
            embeddings.metadata
        FROM embeddings
        WHERE 1 - (embeddings.vector <=> query_vector) > match_threshold
        ORDER BY embeddings.vector <=> query_vector
        LIMIT match_count;
    END;
    \$\$;
    
    -- Crear función para insertar embeddings
    CREATE OR REPLACE FUNCTION insert_embedding(
        p_content text,
        p_vector vector(1536),
        p_metadata jsonb DEFAULT '{}'::jsonb
    )
    RETURNS integer
    LANGUAGE plpgsql
    AS \$\$
    DECLARE
        new_id integer;
    BEGIN
        INSERT INTO embeddings (content, vector, metadata)
        VALUES (p_content, p_vector, p_metadata)
        RETURNING id INTO new_id;
        
        RETURN new_id;
    END;
    \$\$;
    
    -- Crear tabla para documentos RAG
    CREATE TABLE IF NOT EXISTS documents (
        id SERIAL PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        source TEXT,
        chunk_index INTEGER DEFAULT 0,
        embedding vector(1536),
        metadata JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Índice para búsquedas en documentos
    CREATE INDEX IF NOT EXISTS documents_embedding_idx ON documents 
        USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
    
    -- Índice para búsquedas por fuente
    CREATE INDEX IF NOT EXISTS documents_source_idx ON documents (source);
    
    -- Función para búsqueda RAG en documentos
    CREATE OR REPLACE FUNCTION search_documents(
        query_vector vector(1536),
        match_threshold float DEFAULT 0.7,
        match_count int DEFAULT 5
    )
    RETURNS TABLE (
        id integer,
        title text,
        content text,
        source text,
        similarity float,
        metadata jsonb
    )
    LANGUAGE plpgsql
    AS \$\$
    BEGIN
        RETURN QUERY
        SELECT 
            documents.id,
            documents.title,
            documents.content,
            documents.source,
            1 - (documents.embedding <=> query_vector) as similarity,
            documents.metadata
        FROM documents
        WHERE documents.embedding IS NOT NULL
        AND 1 - (documents.embedding <=> query_vector) > match_threshold
        ORDER BY documents.embedding <=> query_vector
        LIMIT match_count;
    END;
    \$\$;
    
    -- Otorgar permisos al usuario actual
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "$DB_USER";
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "$DB_USER";
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO "$DB_USER";

    -- Otorgar permisos en tablas futuras
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "$DB_USER";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "$DB_USER";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO "$DB_USER";

EOSQL

echo "pgvector inicializado correctamente para usuario: $DB_USER"