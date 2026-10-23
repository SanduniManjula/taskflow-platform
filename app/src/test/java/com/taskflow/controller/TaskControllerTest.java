package com.taskflow.controller;

import com.taskflow.dto.TaskRequest;
import com.taskflow.dto.TaskResponse;
import com.taskflow.entity.TaskStatus;
import com.taskflow.exception.ApiExceptionHandler;
import com.taskflow.exception.TaskNotFoundException;
import com.taskflow.service.TaskService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(TaskController.class)
@Import(ApiExceptionHandler.class)
class TaskControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private TaskService service;

    private TaskResponse sampleResponse() {
        Instant now = Instant.parse("2026-01-01T00:00:00Z");
        return new TaskResponse(
                1L, "Write tests", "Test the API",
                TaskStatus.TODO, now, now);
    }

    @Test
    void createReturnsCreatedResponse() throws Exception {
        when(service.create(any(TaskRequest.class)))
                .thenReturn(sampleResponse());

        mockMvc.perform(post("/api/tasks")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Write tests","description":"Test the API"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.title").value("Write tests"))
                .andExpect(jsonPath("$.status").value("TODO"));
    }

    @Test
    void listReturnsTasks() throws Exception {
        when(service.list()).thenReturn(List.of(sampleResponse()));

        mockMvc.perform(get("/api/tasks"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].title").value("Write tests"));
    }

    @Test
    void getReturnsTask() throws Exception {
        when(service.get(1L)).thenReturn(sampleResponse());

        mockMvc.perform(get("/api/tasks/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.title").value("Write tests"));
    }

    @Test
    void updateReturnsUpdatedTask() throws Exception {
        when(service.update(eq(1L), any(TaskRequest.class)))
                .thenReturn(sampleResponse());

        mockMvc.perform(put("/api/tasks/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Write tests","description":"Updated"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Write tests"));
    }

    @Test
    void deleteReturnsNoContent() throws Exception {
        doNothing().when(service).delete(1L);

        mockMvc.perform(delete("/api/tasks/1"))
                .andExpect(status().isNoContent());

        verify(service).delete(1L);
    }

    @Test
    void blankTitleReturnsValidationError() throws Exception {
        mockMvc.perform(post("/api/tasks")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"   ","description":"Invalid task"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").exists());

        verify(service, never()).create(any(TaskRequest.class));
    }

    @Test
    void missingTaskReturnsNotFound() throws Exception {
        when(service.get(999L))
                .thenThrow(new TaskNotFoundException(999L));

        mockMvc.perform(get("/api/tasks/999"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail")
                        .value("Task with id 999 was not found"))
                .andExpect(jsonPath("$.instance").value("/api/tasks/999"));
    }

    @Test
    void malformedJsonReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/tasks")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail")
                        .value("Request contains invalid or malformed values"));
    }

    @Test
    void invalidTaskIdReturnsBadRequest() throws Exception {
        mockMvc.perform(get("/api/tasks/not-a-number"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail")
                        .value("Request contains invalid or malformed values"));
    }

    @Test
    void unexpectedErrorReturnsInternalServerError() throws Exception {
        when(service.list()).thenThrow(new RuntimeException("Internal test error"));

        mockMvc.perform(get("/api/tasks"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.detail")
                        .value("An unexpected error occurred"));
    }
}
