(:
 : SPDX LGPL-2.1-or-later
 : Copyright (C) 2026 The eXist-db Authors
 :)
xquery version "3.1";

(:~
 : Recursive collection and resource utility functions.
 :
 : Provides the eXide-compatible surface (`scan`, `find-by-mimetype`) so apps that
 : carry their own copy of the community `dbutil` (eXide, function-documentation,
 : …) can drop it and import this module instead — the call-sites port by changing
 : only the import namespace. Recursive scans skip subtrees the caller can't read
 : (sm:has-access guard) so they stay resilient for non-dba callers.
 :)
module namespace dbutil="http://exist-db.org/api/dbutils";

declare namespace sm="http://exist-db.org/xquery/securitymanager";

(:~
 : Recursively scan a collection tree, applying a function to each collection.
 :
 : @param $root the root collection path
 : @param $func function to apply to each collection path
 : @return concatenated results of applying $func
 :)
declare function dbutil:scan-collections($root as xs:anyURI, $func as function(xs:anyURI) as item()*) as item()* {
    $func($root),
    (: skip subtrees the caller can't read, rather than letting
       xmldb:get-child-collections throw — keeps a recursive scan resilient
       (mirrors eXide's dbutil, whose guard the original port dropped). :)
    if (sm:has-access($root, "rx")) then
        for $child in xmldb:get-child-collections($root)
        return
            dbutil:scan-collections(xs:anyURI($root || "/" || $child), $func)
    else ()
};

(:~
 : Recursively scan all resources in a collection tree.
 :
 : @param $root the root collection path
 : @param $func function to apply to each (collection, resource) pair
 : @return concatenated results
 :)
declare function dbutil:scan-resources($root as xs:anyURI, $func as function(xs:anyURI, xs:string) as item()*) as item()* {
    (: guarded like scan-collections: skip an unreadable subtree instead of throwing :)
    if (sm:has-access($root, "rx")) then (
        for $resource in xmldb:get-child-resources($root)
        return
            $func($root, $resource),
        for $child in xmldb:get-child-collections($root)
        return
            dbutil:scan-resources(xs:anyURI($root || "/" || $child), $func)
    ) else ()
};

(:~
 : Recursively walk a collection tree, calling $func once per collection (with an
 : empty-sequence resource argument) and once per resource (with the full resource
 : URI). eXide-compatible signature — eXide's `dbutil:scan(...)` call-sites port to
 : this module by changing only the import namespace.
 :
 : @param $root the root collection path
 : @param $func function(collection, resource?) applied per collection and per resource
 : @return concatenated results
 :)
declare function dbutil:scan($root as xs:anyURI, $func as function(xs:anyURI, xs:anyURI?) as item()*) as item()* {
    dbutil:scan-collections($root, function($collection as xs:anyURI) {
        $func($collection, ()),
        if (sm:has-access($collection, "rx")) then
            for $resource in xmldb:get-child-resources($collection)
            return $func($collection, xs:anyURI($collection || "/" || $resource))
        else ()
    })
};

(:~
 : Find every resource in a collection tree whose media type is one of $mimeType.
 : eXide-compatible signature.
 :
 : @param $collection the root collection
 : @param $mimeType one or more media types to match
 : @return matching resource URIs
 :)
declare function dbutil:find-by-mimetype($collection as xs:anyURI, $mimeType as xs:string+) as xs:anyURI* {
    dbutil:scan($collection, function($col as xs:anyURI, $resource as xs:anyURI?) {
        if (exists($resource) and xmldb:get-mime-type($resource) = $mimeType)
        then $resource
        else ()
    })
};

(:~
 : Apply $func to every resource in a collection tree whose media type matches.
 : eXide-compatible signature.
 :
 : @param $collection the root collection
 : @param $mimeType one or more media types to match
 : @param $func function applied to each matching resource URI
 : @return concatenated results of $func
 :)
declare function dbutil:find-by-mimetype($collection as xs:anyURI, $mimeType as xs:string+, $func as function(xs:anyURI) as item()*) as item()* {
    dbutil:scan($collection, function($col as xs:anyURI, $resource as xs:anyURI?) {
        if (exists($resource) and xmldb:get-mime-type($resource) = $mimeType)
        then $func($resource)
        else ()
    })
};

(:~
 : Find all resources matching a pattern in a collection tree.
 :
 : @param $root the root collection
 : @param $pattern resource name pattern (glob)
 : @return sequence of matching resource paths
 :)
declare function dbutil:find-by-name($root as xs:anyURI, $pattern as xs:string) as xs:string* {
    dbutil:scan-resources($root, function($collection, $resource) {
        if (matches($resource, $pattern))
        then $collection || "/" || $resource
        else ()
    })
};

(:~
 : Get the total size of all resources in a collection tree.
 :
 : @param $root the root collection
 : @return total size in bytes
 :)
declare function dbutil:collection-size($root as xs:anyURI) as xs:long {
    sum(
        dbutil:scan-resources($root, function($collection, $resource) {
            xmldb:size($collection, $resource)
        })
    )
};

(:~
 : Count all resources in a collection tree.
 :
 : @param $root the root collection
 : @return total count
 :)
declare function dbutil:resource-count($root as xs:anyURI) as xs:integer {
    count(
        dbutil:scan-resources($root, function($collection, $resource) {
            true()
        })
    )
};
