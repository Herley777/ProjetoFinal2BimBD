/* =========================================================
   PROJETO INTEGRADOR - STREAMFLOW
   Aula 18 - Engenharia de Dados, Performance e BI
   ========================================================= */

DROP DATABASE IF EXISTS streamflow_db;
CREATE DATABASE streamflow_db;
USE streamflow_db;

/* =========================================================
   TABELA: ASSINANTES
   ========================================================= */

CREATE TABLE assinantes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    cpf CHAR(11) NOT NULL UNIQUE,
    data_nascimento DATE NOT NULL,
    uf CHAR(2) NOT NULL,
    metodo_pagamento VARCHAR(50) NOT NULL
);

/* =========================================================
   TABELA: PERFIS
   Cada assinante pode ter até 5 perfis
   ========================================================= */

CREATE TABLE perfis (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_assinante INT NOT NULL,
    nome_exibicao VARCHAR(100) NOT NULL,
    idioma VARCHAR(30) DEFAULT 'Português',
    classificacao_etaria ENUM('Livre','10','12','14','16','18'),

    CONSTRAINT fk_perfis_assinantes
    FOREIGN KEY (id_assinante)
    REFERENCES assinantes(id)
    ON DELETE CASCADE
);

/* =========================================================
   TABELA: PRODUTORAS
   ========================================================= */

CREATE TABLE produtoras (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL
);

/* =========================================================
   TABELA: CONTEUDOS
   FILMES E EPISÓDIOS
   ========================================================= */

CREATE TABLE conteudos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(200) NOT NULL,

    tipo_conteudo ENUM('FILME','EPISODIO') NOT NULL,

    duracao_minutos INT NOT NULL CHECK (duracao_minutos > 0),

    id_produtora INT NOT NULL,

    data_lancamento DATE,

    ativo BOOLEAN DEFAULT TRUE,

    CONSTRAINT fk_conteudos_produtoras
    FOREIGN KEY (id_produtora)
    REFERENCES produtoras(id)
    ON DELETE RESTRICT
);

/* =========================================================
   TABELA: SÉRIES
   ========================================================= */

CREATE TABLE series (
    id INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(200) NOT NULL
);

/* =========================================================
   TABELA: TEMPORADAS
   ========================================================= */

CREATE TABLE temporadas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_serie INT NOT NULL,
    numero_temporada INT NOT NULL,

    CONSTRAINT fk_temporadas_series
    FOREIGN KEY (id_serie)
    REFERENCES series(id)
    ON DELETE CASCADE
);

/* =========================================================
   TABELA: EPISÓDIOS
   ========================================================= */

CREATE TABLE episodios (
    id INT AUTO_INCREMENT PRIMARY KEY,

    id_temporada INT NOT NULL,

    id_conteudo INT NOT NULL UNIQUE,

    CONSTRAINT fk_episodios_temporadas
    FOREIGN KEY (id_temporada)
    REFERENCES temporadas(id)
    ON DELETE CASCADE,

    CONSTRAINT fk_episodios_conteudos
    FOREIGN KEY (id_conteudo)
    REFERENCES conteudos(id)
    ON DELETE RESTRICT
);

/* =========================================================
   TABELA: LOGS DE REPRODUÇÃO
   Não podem ser perdidos
   ========================================================= */

CREATE TABLE logs_reproducao (

    id BIGINT AUTO_INCREMENT PRIMARY KEY,

    id_perfil INT NOT NULL,

    id_conteudo INT NOT NULL,

    data_hora TIMESTAMP NOT NULL
    DEFAULT CURRENT_TIMESTAMP,

    ip VARCHAR(45) NOT NULL,

    dispositivo ENUM(
        'SmartTV',
        'Smartphone',
        'Tablet',
        'Web',
        'Console'
    ) NOT NULL,

    minutos_assistidos INT NOT NULL DEFAULT 0,

    concluido BOOLEAN DEFAULT FALSE,

    CONSTRAINT fk_logs_perfis
    FOREIGN KEY (id_perfil)
    REFERENCES perfis(id)
    ON DELETE RESTRICT,

    CONSTRAINT fk_logs_conteudos
    FOREIGN KEY (id_conteudo)
    REFERENCES conteudos(id)
    ON DELETE RESTRICT
);

/* =========================================================
   ÍNDICE PARA CONTINUAR ASSISTINDO
   ========================================================= */

CREATE INDEX idx_continuar_assistindo
ON logs_reproducao
(
    id_perfil,
    concluido,
    data_hora
);

/* =========================================================
   VIEW LGPD
   ========================================================= */

CREATE VIEW vw_analise_engajamento AS
SELECT

    p.id AS perfil,

    TIMESTAMPDIFF(
        YEAR,
        a.data_nascimento,
        CURDATE()
    ) AS idade,

    a.uf,

    COUNT(l.id) AS total_visualizacoes,

    COALESCE(
        SUM(l.minutos_assistidos),
        0
    ) AS minutos_consumidos

FROM assinantes a

INNER JOIN perfis p
ON p.id_assinante = a.id

LEFT JOIN logs_reproducao l
ON l.id_perfil = p.id

GROUP BY
    p.id,
    idade,
    a.uf;

/* =========================================================
   USUÁRIOS E SEGURANÇA
   ========================================================= */

CREATE USER IF NOT EXISTS 'app_streamflow'
IDENTIFIED BY 'Senha@123';

GRANT SELECT, INSERT, UPDATE
ON streamflow_db.*
TO 'app_streamflow';

CREATE USER IF NOT EXISTS 'auditor'
IDENTIFIED BY 'Auditoria@123';

GRANT SELECT
ON streamflow_db.logs_reproducao
TO 'auditor';

REVOKE DELETE
ON streamflow_db.logs_reproducao
FROM 'app_streamflow';

/* =========================================================
   CONSULTA 1
   CONTINUAR ASSISTINDO
   ========================================================= */

SELECT
    c.titulo,
    l.minutos_assistidos,
    c.duracao_minutos,
    l.data_hora
FROM logs_reproducao l

INNER JOIN conteudos c
ON c.id = l.id_conteudo

WHERE l.id_perfil = 1
AND l.concluido = FALSE

ORDER BY l.data_hora DESC;

/* =========================================================
   CONSULTA 2
   RELATÓRIO BI DAS PRODUTORAS
   ========================================================= */

SELECT

    p.nome AS produtora,

    SUM(l.minutos_assistidos)
    AS minutos_consumidos

FROM produtoras p

INNER JOIN conteudos c
ON c.id_produtora = p.id

INNER JOIN logs_reproducao l
ON l.id_conteudo = c.id

WHERE YEAR(l.data_hora) = 2026
AND MONTH(l.data_hora) = 5

GROUP BY p.nome

HAVING SUM(l.minutos_assistidos) > 300000;

/* =========================================================
   CONSULTA 3
   AUDITORIA DE TRÁFEGO POR REGIÃO
   ========================================================= */

SELECT

    a.uf,

    l.dispositivo,

    COUNT(*) AS total_acessos

FROM logs_reproducao l

INNER JOIN perfis p
ON p.id = l.id_perfil

INNER JOIN assinantes a
ON a.id = p.id_assinante

GROUP BY
    a.uf,
    l.dispositivo

ORDER BY
    total_acessos DESC;

/* =========================================================
   FIM DO PROJETO STREAMFLOW
   ========================================================= */