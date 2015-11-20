This is an overview of Sift modules.

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
      |  +------------------->| SFUploader |
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
