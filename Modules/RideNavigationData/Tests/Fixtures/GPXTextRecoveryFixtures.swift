enum GPXTextRecoveryFixtures {
    static let descriptionsAndNames = #"""
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1">
      <wpt lat="41" lon="2"><desc>Sound & Co and Art & Co</desc></wpt>
      <wpt lat="42" lon="3"><desc>Sound & Co and Art & Co</desc></wpt>
      <trk><name>Forest&Coast</name><trkseg>
        <trkpt lat="41" lon="2"><ele>100</ele><time>2023-11-14T22:13:20.125Z</time></trkpt>
        <trkpt lat="41.01" lon="2.01"><ele>110</ele></trkpt>
      </trkseg><trkseg><trkpt lat="42" lon="3"/></trkseg></trk>
    </gpx>
    """#

    static let preservedXMLContent = #"""
    <gpx>
      <!-- <desc>Leave & alone</desc> -->
      <?example value="leave & alone"?>
      <metadata><name>A &amp; B &lt; C &quot;D&quot; &apos;E&apos; &#38; &#x26; & F</name></metadata>
      <wpt lat="41" lon="2"><desc><![CDATA[Keep & and <name> intact]]></desc></wpt>
      <trk><trkseg><trkpt lat="41" lon="2" note="quoted > &amp; value"/></trkseg></trk>
    </gpx>
    """#

    static let unrecoverableDocuments = [
        #"<gpx><rte><name>A & B</name><rtept lat="41&" lon="2"/></rte></gpx>"#,
        #"<gpx><rte><name>A & B</name><rtept lat="41" lon="2"><ele>1 & 2</ele></rtept></rte></gpx>"#,
        #"<gpx><rte><name>A & B</name><rtept lat="41" lon="2"/></rte>"#,
        #"<gpx><rte><name>A & B</name><rtept lat="41" lon="2"/></rte><trk><trkseg>"#,
        #"<gpx><rte><name>A & B</desc><rtept lat="41" lon="2"/></rte></gpx>"#,
        #"<!DOCTYPE gpx [<!ENTITY custom "value">]><gpx><rte><name>A & B</name><rtept lat="41" lon="2"/></rte></gpx>"#
    ]
}
