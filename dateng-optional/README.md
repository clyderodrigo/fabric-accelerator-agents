# `dateng-optional/` - connection-gated items

Items here require a source connection that the human must create before the agent can deploy
them. They are not part of the default build sequence; the agent adds them after the
corresponding handshake completes.

## Contents

| Folder | Item type | Prerequisite |
| --- | --- | --- |
| `WideWorldImporters-mirror.MirroredDatabase/` | MirroredDatabase | A human-created Azure SQL connection to the source database, returned to the agent before creation |