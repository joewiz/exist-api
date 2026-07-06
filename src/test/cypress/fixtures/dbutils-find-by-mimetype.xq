import module namespace dbutil="http://exist-db.org/api/dbutils";
count(dbutil:find-by-mimetype(xs:anyURI("/db/apps/existdb-openapi/modules"), "application/xquery"))
