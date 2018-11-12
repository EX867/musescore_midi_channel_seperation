import javax.sound.midi.*;
class InstrumentData {
  int tracksCount=1;//getChild(staves).getContent().toInt
  int programNumber=0;//getChild(Channel).getChild(program).getInteger(value) / hasAttribute(name)==false first match
  boolean isPerc=false;//getChild(clef)=="PERC"
  InstrumentData(int tracksCount_, int programNumber_, boolean isPerc_) {
    tracksCount=tracksCount_;
    programNumber=programNumber_;
    isPerc=isPerc_;
  }
  public String toString() {
    return "{track:"+tracksCount+",program:"+programNumber+",perc:"+isPerc+"}";
  }
}
void setup() {
  surface.setTitle("Channel seperation (Musescore midi file import utility");
  size(600, 150);
  translate(width/2, height/2);
  textAlign(CENTER, CENTER);
  textSize(30);
  fill(0);
  text("Select file, and you are done.", 0, 0);
  selectInput("Select midi file to modify (Type 1 midi file):", "process");
}
void draw() {
}
void process(File selection) {
  //https://stackoverflow.com/questions/7063437/midi-timestamp-in-seconds
  //http://www.automatic-pilot.com/midifile.html
  XML instruments=null;
  {//read instruments.xml
    String path=System.getenv("ProgramFiles(X86)")+"/MuseScore 2/instruments/instruments.xml";
    if (new File(path).isFile()) {
      instruments=loadXML(path);
    } else {
      fail("Can't find instruments.xml in "+path);
    }
  }
  //read midi
  if (selection == null) {
    exit();
  } else {
    println("User selected " + selection.getAbsolutePath());
    try {
      Sequence sequence = MidiSystem.getSequence(selection);
      int midiFileType=1;
      try {
        midiFileType=MidiSystem.getMidiFileFormat(selection).getType();
      }
      catch(Exception e) {
        fail(e.toString());
        return;
      }
      if (midiFileType==0) {
        fail("Type 0 midi file detected. This program can only process type 1 midi file.");
      }
      Track[] tracks=sequence.getTracks();

      InstrumentData previousData=null;
      String previousName=null;
      int currentCount=0;
      int channel=1;

      for (int t=0; t<tracks.length; t++) {
        Track track=tracks[t];

        boolean hasProgramChange=false;
        String name=null;
        {//get informations
          for (int a=0; a < track.size(); a++) {
            MidiEvent event = track.get(a);
            MidiMessage message = event.getMessage();
            if (message instanceof ShortMessage && ((ShortMessage)message).getCommand()==ShortMessage.PROGRAM_CHANGE) {//program change
              hasProgramChange=true;
            } else if (message instanceof MetaMessage && ((MetaMessage)message).getType()==0x03) {//track name
              name=new String(((MetaMessage)message).getData()).toLowerCase().trim();
              //println("track name : "+name);
              if (name.contains("/")) {
                name=name.substring(0, name.indexOf("/")).trim();
              }
            }
          }
        }

        InstrumentData data=previousData;
        if ((name==null||!name.equals(previousName))||(previousData==null||previousData.tracksCount<=currentCount)) {//get instrument info (if needed)
          data=null;  
          //if track name changed, or previous instrument used all tracks
          if (name!=null) {
            data=findInstrument(instruments, name);
          }
          if (data==null) {
            data=new InstrumentData(1, 0, false);
          }

          previousData=data;
          if (data.isPerc) {
            channel=9;
          } else {
            channel=channel==0?1:0;
          }
          println("set "+name+" to "+data.programNumber+" at track "+t+" and set channel to "+channel+" / data : "+data+" ("+currentCount+")");
          currentCount=0;
        }
        previousName=name;

        //set channel
        for (int a=0; a < track.size(); a++) {
          MidiEvent event = track.get(a);
          MidiMessage message = event.getMessage();
          if (message instanceof ShortMessage) {
            ShortMessage sm=(ShortMessage)message;
            sm.setMessage(sm.getCommand(), channel, sm.getData1(), sm.getData2());
          }
        }

        //insert program change
        if (!hasProgramChange) {
          ShortMessage programChange = new ShortMessage(ShortMessage.PROGRAM_CHANGE, channel, data.programNumber, 0);
          track.add(new MidiEvent(programChange, (long)0));
        }

        currentCount++;
      }
      String selectionPath=selection.getAbsolutePath();
      MidiSystem.write(sequence, 1, new File(selectionPath.substring(0, selectionPath.length()-4)+"_.mid"));//4 for .mid
    }
    catch(Exception e) {
      fail(e.toString());
      e.printStackTrace();
    }
  }
  exit();
}
void fail(String error) {
  surface.setTitle("Error has been occurred : "+error);
}

HashMap<String, XML> instrumentMap=null;
InstrumentData findInstrument(XML instruments, String id) {
  XML xml, xml2;
  if (instrumentMap==null) {
    instrumentMap=new HashMap<String, XML>();
    for (XML instrumentGroup : instruments.getChildren("InstrumentGroup")) {
      for (XML instrument : instrumentGroup.getChildren("Instrument")) {
        instrumentMap.put(instrument.getString("id"), instrument);
      }
    }
  }

  if ((xml=instrumentMap.get(id))!=null) {
    int tracksCount=1;
    int programNumber=0;
    boolean isPerc=false;
    if ((xml2=xml.getChild("staves"))!=null) {
      tracksCount=xml2.getIntContent();
    }
    if ((xml2=xml.getChild("clef"))!=null) {
      if (xml2.getContent().equals("PERC")) {
        isPerc=true;
      }
    }
    for (XML channel : xml.getChildren("Channel")) {
      if (!channel.hasAttribute("name")) {
        programNumber=channel.getChild("program").getInt("value");
        break;
      }
    }
    return new InstrumentData(tracksCount, programNumber, isPerc);
  }
  return null;
}
