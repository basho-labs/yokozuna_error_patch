# yokozuna_error_patch
Yokozuna modifications to improve error handling and visibility.

## Create an index and schema to hold catastrophic Solr errors

#### Schema

```
curl -XPUT "http://localhost:8098/search/schema/yz_err" \
  -H 'content-type:application/xml' \
  --data-binary @yz_err.xml
```

#### Index

```
curl -XPUT "http://localhost:8098/search/index/yz_err" \
     -H'content-type:application/json' \
     -d'{"schema":"yz_err"}'
```

#### Bucket Type

```
riak-admin bucket-type create yz_err '{"props":{"search_index":"yz_err"}}'
riak-admin bucket-type activate yz_err
```

## Compile this project and patch Riak

```
make
```

Copy the yz_solr.beam into the basho-patches directory. The basho-patches directory for your platform can be found here: [http://docs.basho.com/riak/latest/ops/running/rolling-upgrades/#Basho-Patches](http://docs.basho.com/riak/latest/ops/running/rolling-upgrades/#Basho-Patches)

```
cp -R ebin/* /usr/lib/riak/lib/basho-patches
```