const auth = { username: 'admin', password: '' };
const guest = { username: 'guest', password: 'guest' };

// The dbutils library has no HTTP endpoint, so exercise it through /api/query:
// the query imports the public `api/dbutils` module and runs the call. runQuery
// returns the POST response; value() fetches the (scalar) result from its cursor.
const NS = 'import module namespace dbutil="http://exist-db.org/api/dbutils";\n';

const runQuery = (query, as) =>
  cy.request({ url: '/api/query', method: 'POST', auth: as, body: { query }, failOnStatusCode: false });

const value = (resp, as) =>
  cy.request({ url: `/api/query/${resp.body.cursor}/results?start=1&count=1`, auth: as })
    .then(r => Number(r.body[0].value));

describe('api/dbutils (library, exercised via /api/query)', () => {
  it('find-by-mimetype locates application/xquery resources in a tree', () => {
    const q = NS + 'count(dbutil:find-by-mimetype(xs:anyURI("/db/apps/existdb-openapi/modules"), "application/xquery"))';
    runQuery(q, auth).then(resp => {
      expect(resp.status).to.eq(200);
      value(resp, auth).then(n => expect(n).to.be.greaterThan(0));
    });
  });

  it('scan visits resources across a collection tree', () => {
    const q = NS + 'count(dbutil:scan(xs:anyURI("/db/apps/existdb-openapi/modules"), function($c, $r) { $r }))';
    runQuery(q, auth).then(resp => {
      expect(resp.status).to.eq(200);
      value(resp, auth).then(n => expect(n).to.be.greaterThan(0));
    });
  });

  // Regression: a recursive scan must skip a subtree the caller can't read,
  // not 500. As guest, /db/system holds world-readable config/repo plus security
  // (rwxrwx---, guest outside owner/group); the sm:has-access guard skips security
  // and the scan completes instead of throwing.
  it('scan as guest tolerates an unreadable subtree (no 500)', () => {
    const q = NS + 'count(dbutil:scan(xs:anyURI("/db/system"), function($c, $r) { $r }))';
    runQuery(q, guest).then(resp => {
      expect(resp.status).to.eq(200);
      value(resp, guest).then(n => expect(n).to.be.at.least(0));
    });
  });
});
