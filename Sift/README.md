Here is an overview of Sift modules.

The "unit" of data is an `SFEvent` object.  You create it and send it to
the shared `Sift` object.  The `Sift` object will append that `SFEvent`
to the `SFQueue` you specify.  Under the hood, the `Sift` object will
periodically request `SFUploader` to collect and upload those `SFEvent`
objects from all `SFQueue`.

An `SFQueue` object will accumulate `SFEvent` objects, which will not be
collected by an `SFUploader` before `SFQueue` cuts out a batch of those
`SFEvent` objects.  The batching policy is specified in `SFQueueConfig`.

To have better batching results, you should create queues based on your
batching requirements rather than solely based on event types.  (There
is a default queue, which might be all you need.)

```
  +---------+
  | SFEvent |                         _   _
  +---------+                        ( `   )_
       |                            (   )    `)  )
       |                         (_   (_ .     _)  _)
       v
    +------+                        ^
    | Sift |                        |
    +------+                        | To the cloud
      |  |                          |
      |  |  Request upload    +------------+
      |  \------------------->| SFUploader |
      |                       +------------+
      |                             ^
      | Append event                |
      |                             | Collect events
      |     +-----------------+     |
      +---->| SFQueue         |---->+
      |     |   SFQueueConfig |     |
      |     +-----------------+     |
      |                             |
      |     +-----------------+     |
      +---->| SFQueue         |---->+
      |     |   SFQueueConfig |     |
      |     +-----------------+     |
      |                             |
      |     +-----------------+     |
      +---->| SFQueue         |---->+
      |     |   SFQueueConfig |     |
      |     +-----------------+     |
      |                             |
      .                             .
      .                             .
      .                             .
```

The object tree is illustrated below.  The arrows follow the direction
of ownership.

  * `Sift` owns everything.
  * `SFQueue` owns `SFQueueDirs`.
  * `SFUploader` owns `SFQueueDirs`.
  * `SFQueueDirs` owns `SFRotatedFiles`.

```
               +------+
               | Sift |
               +------+
                  |
       /----------+------------+----------\
       |          |            |          |    +-------------------+
       V          |            V          +--->| SFMetricsReporter |
  +---------+     |      +------------+   |    +-------------------+
  | SFQueue |     |      | SFUploader |   |
  +---------+     |      +------------+   |    +----------------------------+
       |          |            |          \--->| SFDevicePropertiesReporter |
       \-------\  |    /-------/               +----------------------------+
               |  |    |
               V  V    V
            +-------------+
            | SFQueueDirs |
            +-------------+
                   |
                   V
          +----------------+
          | SFRotatedFiles |
          +----------------+
```

The `SFQueueDirs` object manages file system directories (one for each
queue), and guards their concurrent accesses.  The `SFRotatedFiles`
objects are allocated one per directory, which help `SFQueue` manage
files in that directory.
