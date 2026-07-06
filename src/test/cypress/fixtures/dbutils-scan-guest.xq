import module namespace dbutil="http://exist-db.org/api/dbutils";
count(dbutil:scan(xs:anyURI("/db/system"), function($c, $r) { $r }))
