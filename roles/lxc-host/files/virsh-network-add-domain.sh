network="${1:-'default'}"
domain="${2:-'lxc'}"

script -q -c "virsh net-dumpxml '${network}'" >"/tmp/network.xml"

#if ! grep -q 'domain' "/tmp/network.xml"; then
  cat <<EOCAT >"/tmp/add-domain.xslt"
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
   <xsl:template match="@* | node()">
      <xsl:copy>
         <xsl:apply-templates select="@* | node()"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="mac">
      <xsl:copy-of select="."/>
      <domain name="${domain}"/>
   </xsl:template>

</xsl:stylesheet>
EOCAT

  xmlstarlet tr "/tmp/add-domain.xslt" "/tmp/network.xml" | sponge "/tmp/network.xml"
  cat "/tmp/network.xml"
  script -q -c "virsh net-destroy '${network}'"
  script -q -c "virsh net-create '/tmp/network.xml'"
#fi
