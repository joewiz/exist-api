const auth = { username: 'admin', password: '' };
const guest = { username: 'guest', password: 'guest' };

// The dbutils library has no HTTP endpoint, so exercise it through /api/query:
// each test's XQuery lives in a .xq fixture that imports the public `api/dbutils`
// module and runs the call. run() loads the fixture, POSTs it, and yields the
// (scalar) result from its cursor.
const run = (fixture, as) =>
  cy.fixture(fixture, 'utf8').then((query) =>
    cy.request({ url: '/api/query', method: 'POST', auth: as, body: { query }, failOnStatusCode: false })
      .then((resp) => {
        expect(resp.status).to.eq(200);
        return cy.request({ url: `/api/query/${resp.body.cursor}/results?start=1&count=1`, auth: as })
          .then((r) => Number(r.body[0].value));
      }));

describe('api/dbutils (library, exercised via /api/query)', () => {
  it('find-by-mimetype locates application/xquery resources in a tree', () => {
    run('dbutils-find-by-mimetype.xq', auth).then((n) => expect(n).to.be.greaterThan(0));
  });

  it('scan visits resources across a collection tree', () => {
    run('dbutils-scan-tree.xq', auth).then((n) => expect(n).to.be.greaterThan(0));
  });

  // Regression: a recursive scan must skip a subtree the caller can't read,
  // not 500. As guest, /db/system holds world-readable config/repo plus security
  // (rwxrwx---, guest outside owner/group); the sm:has-access guard skips security
  // and the scan completes instead of throwing. dbutils-scan-guest.xq scans /db/system.
  it('scan as guest tolerates an unreadable subtree (no 500)', () => {
    run('dbutils-scan-guest.xq', guest).then((n) => expect(n).to.be.at.least(0));
  });
});
