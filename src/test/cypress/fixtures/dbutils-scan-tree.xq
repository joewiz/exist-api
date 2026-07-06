import module namespace dbutil="http://exist-db.org/api/dbutils";
count(dbutil:scan(xs:anyURI("/db/apps/existdb-openapi/modules"), function($c, $r) { $r }))
