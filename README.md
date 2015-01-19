# yokozuna_error_patch
Yokozuna modifications to improve error handling and visibility.

## Compile this project and patch Riak

```
make
```

Copy the yz_solr.beam into the basho-patches directory. The basho-patches directory for your platform can be found here: [http://docs.basho.com/riak/latest/ops/running/rolling-upgrades/#Basho-Patches](http://docs.basho.com/riak/latest/ops/running/rolling-upgrades/#Basho-Patches)

```
cp -R ebin/yz_kv.beam /usr/lib/riak/lib/basho-patches/yz_kv.beam
```

## Usage

The following are the fields indexed by the yz_err index

* `_yz_err_msg_s`: The string returned by yz_solr:index upon failure. Includes details from solr about the error
* `_yz_err_rb_s`: The bucket from the failed object
* `_yz_err_rk_s`: The key from the failed object
* `_yz_err_rt_s`: The bucket type from the failed object
* `_yz_rb`: The bucket which this new error object is stored. It is the original bucket type concatenated with the original bucket with a "." in between them
* `_yz_rk`: The original key from the failed object is reused for the indexed error object
* `_yz_rt`: The error bucket type is "yz_err"

Following is an example record returned from the query `curl 'http://localhost:8098/search/query/yz_err?wt=json&q=*:*'`: 

```
{
    "_yz_err_msg_s": "{\"Failed to index docs\",\n {ok,\"400\",\n     [{\"Content-Type\",\"application/json; charset=UTF-8\"},\n      {\"Transfer-Encoding\",\"chunked\"}],\n     <<\"{\\\"responseHeader\\\":{\\\"status\\\":400,\\\"QTime\\\":2},\\\"error\\\":{\\\"msg\\\":\\\"Invalid Date String:'blahblahblah'\\\",\\\"code\\\":400}}\\n\">>}}",
    "_yz_err_rb_s": "mybucket",
    "_yz_err_rk_s": "date4",
    "_yz_err_rt_s": "mytype",
    "_yz_id": "1*yz_err*mytype.mybucket*date4*63",
    "_yz_rb": "mytype.mybucket",
    "_yz_rk": "date4",
    "_yz_rt": "yz_err"
}
```

## yz_err bucket type creation

The `yz_err` bucket type and index will be automatically created upon the first execution of the error code. This means that the first error that triggers this code flow can take 15-20+ seconds. To manually trigger this creation, run `riak attach` and run the following erlang snippet:

```
yz_kv:maybe_setup_error_index(yz_index:exists(<<"yz_err">>)).
```