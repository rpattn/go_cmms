{
  "WTGLogEntry": {
    "logId": "string",
    "wtgId": "string",
    "dateTimeUTC": "ISO8601",
    "activityType": "Inspection | Preventive | Corrective | RemoteIntervention | SoftwareUpdate | ParameterChange",
    "workOrderId": "string",
    "trigger": "AlarmId | ScheduleId | RCARecommendation | InspectionFinding",
    "personnel": ["string"],
    "proceduresUsed": ["DocRef"],
    "findings": "string",
    "partsUsed": [
      {
        "partId": "string",
        "serialOrBatch": "string",
        "quantity": 1
      }
    ],
    "testResults": ["DocRef"],
    "photos": [
      {
        "uri": "string",
        "geoTag": "lat,lon",
        "resolution": "pixels"
      }
    ],
    "signOff": {
      "by": "string",
      "dateTimeUTC": "ISO8601",
      "version": "string"
    }
  },
  "MonthlyReport": {
    "siteId": "string",
    "period": "YYYY-MM",
    "availability": {
      "technical": "percent",
      "commercial": "percent"
    },
    "kpis": {
      "alarmsRaised": "number",
      "alarmsClosed": "number",
      "meanTimeToRepairHours": "number",
      "meanTimeBetweenFailuresHours": "number"
    },
    "events": [
      {
        "eventId": "string",
        "wtgId": "string",
        "startUTC": "ISO8601",
        "endUTC": "ISO8601",
        "category": "Planned | Unplanned",
        "rootCause": "string",
        "downtimeHours": "number",
        "vesselTimeHours": "number"
      }
    ],
    "spares": [
      {
        "partId": "string",
        "category": "Major (Y-A.1) | Minor (Y-A.2)",
        "quantityConsumed": "number",
        "remainingStock": "number",
        "expiryDate": "YYYY-MM-DD"
      }
    ],
    "bim": {
      "inspections": "number",
      "findingsByClass": {
        "M": "number",
        "M-Nx": "number",
        "RM-1": "number",
        "RM-2": "number"
      }
    }
  },
  "GoldenParameters": {
    "wtgModel": "string",
    "swBaseline": "string",
    "parameters": [
      {
        "name": "string",
        "value": "number|string|boolean",
        "units": "string",
        "tolerance": "±value or range",
        "safetyCritical": true
      }
    ],
    "version": "string",
    "effectiveDate": date
    }
  }
}
    "effectiveDateUTC": "ISO8601"
  }
}
