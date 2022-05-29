import 'package:cw_ldk/cw_ldk.dart';

import 'package:flutter/material.dart';

class NodeAndChannelInfoPage extends StatefulWidget {
  @override
  State<NodeAndChannelInfoPage> createState() => _NodeAndChannelInfoState();
}

class _NodeAndChannelInfoState extends State<NodeAndChannelInfoPage> {
  String nodeInfo;
  String channelInfo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Node and Channel Info")),
        body: Center(
          child: Column(
            children: [
              Text("node info: $nodeInfo"),
              Text("channel info: $channelInfo"),
            ],
          ),
        ));
  }

  @override
  void initState() {
    super.initState();
    initStateAsync();
  }

  void initStateAsync() async {
    final _nodeInfo = await CwLdk.nodeInfo();
    final _channelInfo = await CwLdk.listChannels();
    setState(() {
      nodeInfo = _nodeInfo;
      channelInfo = _channelInfo;
    });
  }
}
