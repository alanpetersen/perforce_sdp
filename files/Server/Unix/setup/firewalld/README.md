Sample Firewall Configuration
==

Overview
--

This directory contains sample _service_ files for the _firewalld_ firewall service to 'poke a hole' in the firewall enabling access to Perforce. If the firewalld service is used, these sample files may prove useful. To use these files:

1. For each instance, create your own *p4d__N_.xml* file, copying from *p4d_1.xml*.  Here _N_ is the instance name, e.g. '2' or 'acme'.
If your instance has a broker, proxy, or other component that is to run on the current machine, create additional files as needed.  See the *p4broker_1.xml* file as an example.

2. Modify your XML files, changing the port number, short name, and description fields as desired.  Keep the short name the same as the file (less the .xml extension).  For example, p4d_1.xml might look like this:
<PRE>
   &lt;?xml version="1.0" encoding="utf-8"?&gt;
   &lt;service&gt;
     &lt;short&gt;p4d_1&lt;/short&gt;
     &lt;description&gt;Enable access to Helix Server on port 1666.&lt;/description&gt;
     &lt;port protocol="tcp" port="1666"/&gt;
   &lt;/service&gt;
</PRE>

3. As root, copy your modified <CODE>p4*.xml</CODE> files to the <CODE>/etc/firewalld/services</CODE> directory.

4. As root, run commands like these samples, substituting the service name:

<PRE>
firewall-cmd --reload
firewall-cmd --permanent --zone=public --add-service p4d_1
firewall-cmd --permanent --zone=public --add-service p4broker_1
firewall-cmd --reload
iptables-save
</PRE>

In these samples, the default _public_ security zone is used.  Further reading of the *firewalld* and *firewall-cmd* man pages is recommended for a more detailed understanding of *firewalld* configuration.

Which Ports to Open?
--

This example exposes ports for both p4d and p4broker processes.  For replication, the P4TARGET values configured for replicas should bypass the broker  and go direct to p4d.  Ports for both p4d and p4broker must be open.  Having them both open in the same public zone would allow regular users to potentially bypass the broker and access p4d directly (unless prevented by other means).  This may well be intended behavior.

A more sophisticated firewall configuration could be configured such that the broker port is exposed in the public zone, while the direct p4d port is exposed in a separate zone accessible only by other server machines.  This could allow replicas but not regular users to bypass the broker.
