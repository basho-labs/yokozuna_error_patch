# yokozuna_error_patch
Yokozuna modifications to improve error handling and visibility.

## Compile this project and patch Riak

```
make
```

Copy the yz_solr.beam into the basho-patches directory. The basho-patches directory for your platform can be found here: [http://docs.basho.com/riak/latest/ops/running/rolling-upgrades/#Basho-Patches](http://docs.basho.com/riak/latest/ops/running/rolling-upgrades/#Basho-Patches)

```
cp -R ebin/* /usr/lib/riak/lib/basho-patches
```