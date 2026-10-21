package com.taskflow.controller;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class HealthControllerTest {
    @Test
    void healthHasExpectedStatus() {
        var response = new HealthController().health();
        assertEquals("UP", response.get("status"));
        assertEquals("taskflow", response.get("service"));
        assertNotNull(response.get("timestamp"));
    }
}
