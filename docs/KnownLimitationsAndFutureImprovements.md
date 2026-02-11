# Known Limitations and Future Improvements

## Known Limitations
- The system currently depends on a single keeper flow; if keeper configuration is missing, liquidation automation is reduced.
- Frontend branch coverage is still lower than line/function coverage, especially in some edge-case UI paths.
- Oracle and indexing behavior can be affected by upstream RPC limits (for example `eth_getLogs` range limits on free-tier providers).
- Deployment and environment configuration are still manual and require careful address synchronization across `contracts`, `backend`, and `frontend`.

## Future Improvements
- Add multi-keeper support, keeper health monitoring, and alerting to improve liquidation reliability.
- Expand frontend tests for edge-case branches and add E2E tests (wallet + transaction flows) with CI execution.
- Introduce deployment automation scripts to generate and propagate contract addresses automatically.
- Add stricter runtime guards and observability (structured metrics, dashboards, and failure recovery playbooks).
