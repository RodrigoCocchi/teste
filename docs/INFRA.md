# Infra — o que o servidor precisa aguentar

## O ponto mais importante

**O 3D roda no navegador de quem acessa**, não no servidor. O servidor só serve a página,
a API, o banco, as filas e chama as APIs de IA (Anthropic/OpenAI), que processam fora.
Portanto **não precisa de servidor com GPU** para esta arquitetura.

GPU no servidor só seria necessária se optar por Unreal Engine com Pixel Streaming —
não é o caminho deste projeto.

## Configuração recomendada

| Fase | vCPU | RAM | Disco | Observação |
|---|---|---|---|---|
| Desenvolvimento / demo | 2 | 4 GB | 40 GB SSD | Só você usando |
| MVP com 1–5 clientes | 4 | 8 GB | 80 GB SSD | Confortável para Postgres + Redis + workers |
| Agentes Dev com sandbox ativo | 8 | 16 GB | 160 GB SSD | Cada container de sandbox consome CPU/RAM |

Requisitos gerais:
- Linux (Ubuntu 24.04 LTS)
- Docker + Docker Compose
- IP fixo, portas 80/443 abertas
- Backup diário do Postgres (snapshot do provedor ou pg_dump para storage externo)
- Domínio próprio apontando para o servidor (Caddy emite o HTTPS sozinho)

## O que comparar entre provedores
- Preço mensal da faixa de 4 vCPU / 8 GB
- Região (São Paulo reduz latência para clientes no Brasil)
- Snapshots/backup incluídos
- Cobrança de tráfego de saída
- Facilidade de subir de plano depois sem migrar

## Custo que pesa de verdade
O maior custo variável tende a ser o **consumo das APIs de IA**, não o servidor.
Por isso o projeto tem orçamento de tokens por tenant, roteamento de modelo e cache de prompt.

## Máquina para gravar os vídeos
Quem precisa de GPU boa é o computador onde você abre o escritório para gravar:
placa de vídeo dedicada intermediária já entrega o modo cinematográfico a 60 fps.
